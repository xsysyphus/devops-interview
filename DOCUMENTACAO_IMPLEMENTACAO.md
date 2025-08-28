# Documentação Técnica - API Segura com mTLS na AWS

## Índice

1. [Visão Geral da Arquitetura](#1-visão-geral-da-arquitetura)
2. [Decisões Técnicas](#2-decisões-técnicas)
3. [Infraestrutura como Código](#3-infraestrutura-como-código)
4. [Configuração de Segurança](#4-configuração-de-segurança)
5. [Pipeline CI/CD](#5-pipeline-cicd)
6. [Comandos Úteis](#6-comandos-úteis)
7. [Monitoramento e Observabilidade](#7-monitoramento-e-observabilidade)
8. [Boas Práticas de Segurança](#8-boas-práticas-de-segurança)
9. [Checklist de Validação](#9-checklist-de-validação)
10. [Guia de Troubleshooting](#10-guia-de-troubleshooting)

---

## 1. Visão Geral da Arquitetura

### Componentes Principais

A solução implementa uma API Python Flask protegida por mTLS (mutual TLS) utilizando AWS ECS Fargate como plataforma de containers. A arquitetura segue princípios de segurança por camadas e alta disponibilidade.

### Diagrama da Arquitetura

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│    Cliente      │    │   Route 53 DNS   │    │       NLB       │
│  + Certificado  │───▶│api.bodyharmony   │───▶│ SSL Passthrough │
│     mTLS        │    │     .life        │    │   Port 443      │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                                         │
                       ┌─────────────────────────────────┼─────────────────────────────────┐
                       │                    VPC          │                                 │
                       │  ┌─────────────────────────────┼─────────────────────────────┐   │
                       │  │          Private Subnets    │                             │   │
                       │  │                             ▼                             │   │
                       │  │  ┌─────────────────┐  ┌─────────────────┐                │   │
                       │  │  │  Nginx Service  │  │  Nginx Service  │                │   │
                       │  │  │ (mTLS Gateway)  │  │ (mTLS Gateway)  │                │   │
                       │  │  │   Container 1   │  │   Container 2   │                │   │
                       │  │  └─────────┬───────┘  └─────────┬───────┘                │   │
                       │  │            │                    │                        │   │
                       │  │            └──────────┬─────────┘                        │   │
                       │  │                       │                                  │   │
                       │  │                       ▼                                  │   │
                       │  │            ┌─────────────────────────────┐               │   │
                       │  │            │     Service Discovery       │               │   │
                       │  │            │   api.teste-api.local       │               │   │
                       │  │            └─────────────┬───────────────┘               │   │
                       │  │                          │                               │   │
                       │  │                          ▼                               │   │
                       │  │  ┌─────────────────┐  ┌─────────────────┐                │   │
                       │  │  │   API Service   │  │   API Service   │                │   │
                       │  │  │ Python Flask    │  │ Python Flask    │                │   │
                       │  │  │  Container 1    │  │  Container 2    │                │   │
                       │  │  └─────────────────┘  └─────────────────┘                │   │
                       │  └─────────────────────────────────────────────────────────┘   │
                       └─────────────────────────────────────────────────────────────────┘
```

### Stack Tecnológico

- **Cloud Provider**: AWS
- **Containers**: ECS Fargate
- **Load Balancer**: Network Load Balancer (NLB)
- **API**: Python Flask
- **Proxy/Gateway**: Nginx com mTLS
- **Service Discovery**: AWS Cloud Map
- **Registry**: Amazon ECR
- **IaC**: Terraform
- **CI/CD**: GitHub Actions + PowerShell Scripts
- **Monitoring**: CloudWatch
- **Security**: WAF v2, Security Groups, mTLS

---

## 2. Decisões Técnicas

### Requisitos Pré-Definidos

Os seguintes componentes foram **definidos como requisitos obrigatórios** no desafio:

- **ECS Fargate**: Plataforma de containers serverless
- **Load Balancer Público**: Para exposição da aplicação
- **Nginx com mTLS**: Gateway de autenticação obrigatória
- **GitHub Actions**: Pipeline de CI/CD
- **API Python**: Aplicação Flask fornecida

### Decisões de Implementação

#### Network Load Balancer vs Application Load Balancer

**Decisão crítica:** Inicialmente foi implementado Application Load Balancer (ALB), mas foi migrado para NLB durante o troubleshooting.

**Problema identificado com ALB:**
- Terminava o SSL/TLS, impedindo o mTLS no Nginx
- Não passava certificados cliente para downstream
- Incompatível com autenticação mútua end-to-end

**Solução implementada com NLB:**
- **SSL Passthrough**: Mantém conexão TLS end-to-end
- **Performance**: Layer 4, menor latência
- **mTLS**: Permite validação de certificado cliente no Nginx

**Implementação escolhida:**
- **Endpoints públicos**: /health sem autenticação
- **Endpoints protegidos**: Todos os demais com mTLS obrigatório
- **Validação granular**: Por location no Nginx

**Configuração implementada:**
```nginx
ssl_verify_client optional;
ssl_client_certificate /etc/nginx/certs/ca.crt;

# Health check sem mTLS
location /health {
    return 200 "OK";
}

# API com mTLS obrigatório
location / {
    if ($ssl_client_verify != "SUCCESS") {
        return 403;
    }
    proxy_pass http://api.teste-api.local:5000;
}
```

#### Service Discovery (AWS Cloud Map)

**Justificativa da escolha:**
- **DNS dinâmico**: Resolução automática de IPs das tasks
- **Health checks**: Remoção automática de instâncias não saudáveis
- **Multi-AZ**: Distribuição automática de carga
- **Integração ECS**: Registro automático de tasks

---

## 3. Infraestrutura como Código

### Estrutura do Projeto

```
devops-interview/
├── terraform/
│   ├── main.tf           # Provider e backend
│   ├── variables.tf      # Variáveis globais
│   ├── network.tf        # VPC, subnets, gateways
│   ├── security.tf       # Security Groups
│   ├── ecr.tf           # Container registries
│   ├── ecs.tf           # Cluster, services, tasks
│   ├── alb.tf           # Network Load Balancer
│   ├── waf.tf           # Web Application Firewall
│   ├── monitoring.tf    # CloudWatch dashboards
│   └── outputs.tf       # Outputs do Terraform
├── nginx/
│   ├── Dockerfile       # Imagem Nginx customizada
│   ├── nginx.conf       # Configuração mTLS
│   └── certs/           # Certificados SSL/mTLS
├── api/
│   ├── app.py          # Aplicação Python Flask
│   ├── Dockerfile      # Imagem da API
│   └── requirements.txt # Dependências Python
├── .github/workflows/
│   └── deploy.yml      # Pipeline GitHub Actions
└── *.ps1               # Scripts de deploy manual
```

### Componentes Terraform

#### Network (network.tf)
```hcl
# VPC principal
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
}

# Subnets públicas para NLB
resource "aws_subnet" "public" {
  count  = length(var.public_subnet_cidrs)
  vpc_id = aws_vpc.main.id
  # ... configurações de AZ e CIDR
}

# Subnets privadas para ECS
resource "aws_subnet" "private" {
  count  = length(var.private_subnet_cidrs)
  vpc_id = aws_vpc.main.id
  # ... configurações de AZ e CIDR
}
```

#### Security Groups (security.tf)
```hcl
# Nginx - aceita HTTPS de qualquer lugar
resource "aws_security_group" "nginx" {
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# API - aceita apenas do Nginx
resource "aws_security_group" "api" {
  ingress {
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.nginx.id]
  }
}
```

#### ECS Services (ecs.tf)
```hcl
# Task Definition do Nginx
resource "aws_ecs_task_definition" "nginx" {
  family                   = "${var.project_name}-nginx-task"
  requires_compatibilities = ["FARGATE"]
  network_mode            = "awsvpc"
  cpu                     = 256
  memory                  = 512
  
  container_definitions = jsonencode([{
    name  = "${var.project_name}-nginx-container"
    image = "${aws_ecr_repository.nginx.repository_url}:latest"
    portMappings = [{
      containerPort = 443
      protocol      = "tcp"
    }]
    # ... logs e outras configurações
  }])
}
```

### Deploy da Infraestrutura

```bash
# 1. Inicializar Terraform
cd terraform
terraform init

# 2. Planejar mudanças
terraform plan

# 3. Aplicar infraestrutura
terraform apply
```

---

## 4. Configuração de Segurança

### Geração de Certificados mTLS

#### Script de Geração (nginx/certs/gerar_certificados.sh)

```bash
#!/bin/bash

# Configurações
COUNTRY="BR"
STATE="Sao Paulo"
CITY="Sao Paulo"
ORG_CA="Minha CA"
ORG_SERVER="Meu Servidor"
ORG_CLIENT="Meu Cliente"
COMMON_NAME_SERVER="[SEU_DOMINIO_OU_IP]"

# 1. Gerar CA (Certificate Authority)
openssl req -new -x509 -days 3650 -extensions v3_ca \
  -keyout ca.key -out ca.crt \
  -subj "/C=$COUNTRY/ST=$STATE/L=$CITY/O=$ORG_CA/CN=Minha Autoridade Certificadora"

# 2. Gerar chave privada do servidor
openssl genrsa -out server.key 2048

# 3. Gerar CSR do servidor
openssl req -new -key server.key -out server.csr \
  -subj "/C=$COUNTRY/ST=$STATE/L=$CITY/O=$ORG_SERVER/CN=$COMMON_NAME_SERVER"

# 4. Assinar certificado do servidor com CA
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key \
  -CAcreateserial -out server.crt -days 825

# 5. Gerar chave privada do cliente
openssl genrsa -out cliente-$(date +%Y%m%d-%H%M%S).key 2048

# 6. Gerar CSR do cliente
openssl req -new -key cliente-*.key -out cliente.csr \
  -subj "/C=$COUNTRY/ST=$STATE/L=$CITY/O=$ORG_CLIENT/CN=Cliente Autorizado"

# 7. Assinar certificado do cliente com CA
openssl x509 -req -in cliente.csr -CA ca.crt -CAkey ca.key \
  -CAcreateserial -out cliente-$(date +%Y%m%d-%H%M%S).crt -days 825

# 8. Criar fullchain para Nginx
cat server.crt ca.crt > server.fullchain.crt
```

### Configuração mTLS do Nginx

#### nginx.conf
```nginx
worker_processes 1;

events {
    worker_connections 1024;
}

http {
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    client_max_body_size 10M;

    server {
        listen 443 ssl;
        server_name [SEU_DOMINIO_OU_IP];

        # Certificados SSL/TLS
        ssl_certificate /etc/nginx/certs/server.fullchain.crt;
        ssl_certificate_key /etc/nginx/certs/server.key;
        
        # Protocolos e cifras seguros
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256;
        ssl_prefer_server_ciphers off;

        # Configurações mTLS
        ssl_client_certificate /etc/nginx/certs/ca.crt;
        ssl_verify_client optional;
        ssl_verify_depth 2;

        # Health check público (sem mTLS)
        location /health {
            access_log off;
            return 200 "OK";
            add_header Content-Type text/plain;
        }

        # API protegida (com mTLS)
        location / {
            # Verificar certificado cliente
            if ($ssl_client_verify != "SUCCESS") {
                return 403;
            }
            
            # Timeouts
            proxy_connect_timeout 30s;
            proxy_send_timeout 30s;
            proxy_read_timeout 30s;
            
            # Headers para API
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Client-Verify $ssl_client_verify;
            proxy_set_header X-Client-S-DN $ssl_client_s_dn;
            proxy_set_header X-Client-I-DN $ssl_client_i_dn;
            proxy_set_header X-Client-Serial $ssl_client_serial;

            # Proxy para Service Discovery
            proxy_pass http://api.teste-api.local:5000;
        }
    }
}
```

---

## 5. Pipeline CI/CD

### GitHub Actions

#### .github/workflows/deploy.yml
```yaml
name: Deploy to AWS ECS

on:
  push:
    branches: [ main ]
  workflow_dispatch:

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v3
    
    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v2
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: ${{ secrets.AWS_REGION }}
    
    - name: Login to Amazon ECR
      id: login-ecr
      uses: aws-actions/amazon-ecr-login@v1
    
    - name: Build and push API image
      run: |
        docker build -t ${{ secrets.ECR_REPOSITORY_API }} ./api
        docker tag ${{ secrets.ECR_REPOSITORY_API }}:latest \
          ${{ secrets.ECR_REGISTRY }}/${{ secrets.ECR_REPOSITORY_API }}:latest
        docker push ${{ secrets.ECR_REGISTRY }}/${{ secrets.ECR_REPOSITORY_API }}:latest
    
    - name: Build and push Nginx image
      run: |
        docker build -t ${{ secrets.ECR_REPOSITORY_NGINX }} ./nginx
        docker tag ${{ secrets.ECR_REPOSITORY_NGINX }}:latest \
          ${{ secrets.ECR_REGISTRY }}/${{ secrets.ECR_REPOSITORY_NGINX }}:latest
        docker push ${{ secrets.ECR_REGISTRY }}/${{ secrets.ECR_REPOSITORY_NGINX }}:latest
    
    - name: Force ECS deployment
      run: |
        aws ecs update-service \
          --cluster ${{ secrets.ECS_CLUSTER_NAME }} \
          --service ${{ secrets.ECS_SERVICE_API }} \
          --force-new-deployment
        aws ecs update-service \
          --cluster ${{ secrets.ECS_CLUSTER_NAME }} \
          --service ${{ secrets.ECS_SERVICE_NGINX }} \
          --force-new-deployment
```

### Scripts de Deploy Manual

#### deploy.ps1 (PowerShell)
```powershell
# Script para deploy manual via PowerShell
$awsRegion = "[SUA_REGIAO_AWS]"
$ecrRegistry = "[SEU_ECR_REGISTRY_URL]"
$ecsCluster = "[SEU_PROJETO]-cluster"

# Login no ECR
wsl aws ecr get-login-password --region $awsRegion | docker login --username AWS --password-stdin $ecrRegistry

# Build e push das imagens
docker build -t [SEU_PROJETO]-api ./api/
docker tag [SEU_PROJETO]-api:latest $ecrRegistry/[SEU_PROJETO]-api:latest
docker push $ecrRegistry/[SEU_PROJETO]-api:latest

docker build -t [SEU_PROJETO]-nginx ./nginx/
docker tag [SEU_PROJETO]-nginx:latest $ecrRegistry/[SEU_PROJETO]-nginx:latest
docker push $ecrRegistry/[SEU_PROJETO]-nginx:latest

# Deploy dos serviços
wsl aws ecs update-service --cluster $ecsCluster --service [SEU_PROJETO]-api-service --force-new-deployment --region $awsRegion
wsl aws ecs update-service --cluster $ecsCluster --service [SEU_PROJETO]-nginx-service --force-new-deployment --region $awsRegion
```

---

## 6. Comandos Úteis

### Testes e Validação

#### Comandos de Teste Principais
```bash
# 1. Health check (sem certificado) - deve retornar 200
curl -k https://[SEU_NLB_DNS]/health

# 2. API sem certificado (deve retornar 403)
curl -k https://[SEU_NLB_DNS]/api/webhook

# 3. API com certificado válido (deve retornar 200)
curl -k --cert ./nginx/certs/cliente-[TIMESTAMP].crt \
  --key ./nginx/certs/cliente-[TIMESTAMP].key \
  https://[SEU_NLB_DNS]/api/webhook \
  -H "Content-Type: application/json" \
  -d '{"test": "data"}'

# 4. Endpoint raiz da API
curl -k --cert ./nginx/certs/cliente-[TIMESTAMP].crt \
  --key ./nginx/certs/cliente-[TIMESTAMP].key \
  https://[SEU_NLB_DNS]/
```

### Comandos AWS CLI

#### ECS Management
```bash
# Listar services em execução
aws ecs list-services --cluster [SEU_PROJETO]-cluster --region [SUA_REGIAO]

# Verificar status das tasks
aws ecs list-tasks --cluster [SEU_PROJETO]-cluster --service-name [SEU_PROJETO]-api-service --region [SUA_REGIAO]

# Forçar novo deployment
aws ecs update-service --cluster [SEU_PROJETO]-cluster --service [SEU_PROJETO]-api-service --force-new-deployment --region [SUA_REGIAO]

# Ver logs de uma task específica
aws logs filter-log-events --log-group-name "/ecs/teste-api/api" --region [SUA_REGIAO]
```

#### ECR Management
```bash
# Login no ECR
aws ecr get-login-password --region [SUA_REGIAO] | docker login --username AWS --password-stdin [SEU_ECR_REGISTRY_URL]

# Listar repositórios
aws ecr describe-repositories --region [SUA_REGIAO]

# Listar imagens de um repositório
aws ecr list-images --repository-name [SEU_PROJETO]-api --region [SUA_REGIAO]
```

#### Service Discovery
```bash
# Listar services de Service Discovery
aws servicediscovery list-services --region [SUA_REGIAO]

# Listar instâncias registradas
aws servicediscovery list-instances --service-id srv-4odn4aaq5nbwgxoj --region [SUA_REGIAO]

# Remover instância órfã
aws servicediscovery deregister-instance --service-id srv-4odn4aaq5nbwgxoj --instance-id INSTANCE_ID --region [SUA_REGIAO]
```

### Debug e Troubleshooting

#### Verificar Certificados
```bash
# Verificar certificado do servidor
openssl x509 -in nginx/certs/server.crt -text -noout

# Verificar certificado da CA
openssl x509 -in nginx/certs/ca.crt -text -noout

# Verificar certificado do cliente
openssl x509 -in nginx/certs/cliente-*.crt -text -noout

# Testar conexão SSL
openssl s_client -connect [SEU_NLB_DNS]:443 -cert nginx/certs/cliente-*.crt -key nginx/certs/cliente-*.key
```

#### Logs em Tempo Real
```bash
# Logs do Nginx
aws logs tail "/ecs/teste-api/nginx" --follow --region [SUA_REGIAO]

# Logs da API
aws logs tail "/ecs/teste-api/api" --follow --region [SUA_REGIAO]

# Logs com filtro de erro
aws logs filter-log-events --log-group-name "/ecs/teste-api/nginx" --filter-pattern "ERROR" --region [SUA_REGIAO]
```

---

## 7. Monitoramento e Observabilidade

### CloudWatch Dashboard

#### Métricas Implementadas
- **Network Load Balancer**: ActiveFlowCount, ConsumedLCUs, HealthyHostCount
- **ECS Services**: CPUUtilization, MemoryUtilization por serviço
- **WAF**: AllowedRequests, BlockedRequests (quando habilitado)

#### dashboard.tf
```hcl
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-dashboard-${var.environment}"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        properties = {
          metrics = [
            ["AWS/NetworkELB", "ActiveFlowCount", "LoadBalancer", aws_lb.main.name],
            ["AWS/ECS", "CPUUtilization", "ClusterName", aws_ecs_cluster.main.name, "ServiceName", aws_ecs_service.nginx.name]
          ]
          view    = "timeSeries"
          region  = var.aws_region
          title   = "Infrastructure Metrics"
        }
      }
    ]
  })
}
```

### 🔍 Log Groups
- `/ecs/teste-api/nginx`: Logs do Nginx (access e error)
- `/ecs/teste-api/api`: Logs da aplicação Python Flask

### 📈 Alertas Sugeridos
```bash
# CPU alta no ECS
aws cloudwatch put-metric-alarm \
  --alarm-name "ECS-High-CPU" \
  --alarm-description "ECS CPU Utilization > 80%" \
  --metric-name CPUUtilization \
  --namespace AWS/ECS \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold
```

---

## 8. Boas Práticas de Segurança

### 🔒 Implementadas

#### Network Security
- **VPC isolada**: Subnets privadas para aplicação
- **Security Groups**: Regras específicas por componente
- **NLB público**: Apenas NLB exposto à internet
- **Service Discovery**: Comunicação interna por DNS

#### Application Security
- **mTLS**: Autenticação mútua obrigatória
- **SSL/TLS 1.2+**: Protocolos seguros apenas
- **Strong Ciphers**: Cifras modernas e seguras
- **Certificate Rotation**: Certificados com validade limitada

#### Infrastructure Security
- **IAM Roles**: Least privilege principle
- **ECR**: Imagens privadas
- **CloudWatch**: Logs centralizados
- **WAF**: Proteção contra ataques web

## 9. Checklist de Validação

### ✅ Infraestrutura

- [ ] **VPC criada** com subnets públicas e privadas
- [ ] **NLB funcionando** com SSL passthrough
- [ ] **ECS Cluster** com services rodando
- [ ] **Service Discovery** resolvendo DNS interno
- [ ] **ECR repositories** criados e funcionais
- [ ] **Security Groups** configurados corretamente
- [ ] **CloudWatch** coletando logs e métricas

### ✅ Aplicação

- [ ] **API Python** respondendo na porta 5000
- [ ] **Nginx** funcionando como proxy reverso
- [ ] **Certificados SSL/TLS** válidos e configurados
- [ ] **Health check** acessível sem autenticação
- [ ] **Endpoints da API** protegidos por mTLS

### ✅ Segurança

- [ ] **mTLS configurado** e funcionando
- [ ] **Certificados cliente** válidos gerados
- [ ] **Rejeição sem certificado** (403 Forbidden)
- [ ] **Aceitação com certificado** (200 OK)
- [ ] **SSL/TLS protocols** seguros (1.2+)
- [ ] **Strong ciphers** configurados

### ✅ Testes

- [ ] **Teste 1**: `curl /health` → 200 OK
- [ ] **Teste 2**: `curl /api/webhook` → 403 Forbidden
- [ ] **Teste 3**: `curl --cert --key /api/webhook` → 200 OK
- [ ] **Performance**: Response time < 1s
- [ ] **Load test**: Múltiplas requisições simultâneas

### ✅ DevOps

- [ ] **IaC com Terraform** aplicado sem erros
- [ ] **Pipeline CI/CD** configurado
- [ ] **Deploy manual** funcionando
- [ ] **Rollback** testado
- [ ] **Documentação** completa

---

## 10. Guia de Troubleshooting

### 🚨 Problemas Comuns

#### 1. Erro 403 Forbidden para /health

**Sintoma**: Health check retorna 403
```bash
curl https://nlb-dns/health
# → 403 Forbidden
```

**Causa**: Configuração incorreta do mTLS no Nginx

**Solução**:
```nginx
# Certificar que /health não exige mTLS
location /health {
    # Não adicionar ssl_verify_client on aqui
    return 200 "OK";
}
```

#### 2. Erro 502 Bad Gateway

**Sintoma**: API retorna 502
```bash
curl --cert client.crt --key client.key https://nlb-dns/api/webhook
# → 502 Bad Gateway
```

**Possíveis Causas**:
1. Service Discovery com IPs antigos
2. API não está rodando
3. Timeout de conexão

**Diagnóstico**:
```bash
# Verificar tasks ativas
aws ecs list-tasks --cluster [SEU_PROJETO]-cluster --service-name [SEU_PROJETO]-api-service

# Verificar Service Discovery
aws servicediscovery list-instances --service-id srv-4odn4aaq5nbwgxoj

# Verificar logs do Nginx
aws logs filter-log-events --log-group-name "/ecs/teste-api/nginx" --start-time $(date -d '5 minutes ago' +%s)000
```

**Solução**:
```bash
# Limpar instâncias órfãs do Service Discovery
aws servicediscovery deregister-instance --service-id srv-4odn4aaq5nbwgxoj --instance-id OLD_INSTANCE_ID

# Forçar redeploy
aws ecs update-service --cluster [SEU_PROJETO]-cluster --service teste-api-nginx-service --force-new-deployment
```

#### 3. Erro 504 Gateway Timeout

**Sintoma**: Timeout após 30+ segundos
```bash
curl --cert client.crt --key client.key https://nlb-dns/api/webhook
# → 504 Gateway Timeout
```

**Causa**: Nginx não consegue conectar na API

**Diagnóstico**:
```bash
# Verificar se Service Discovery está resolvendo
nslookup api.teste-api.local  # Deve falhar de fora da VPC

# Verificar IPs registrados vs IPs reais das tasks
aws servicediscovery list-instances --service-id srv-4odn4aaq5nbwgxoj
aws ecs describe-tasks --cluster [SEU_PROJETO]-cluster --tasks TASK_ID
```

**Solução**: Mesmo que item anterior

#### 4. Certificado Inválido/Expirado

**Sintoma**: Erro SSL handshake
```bash
curl: (35) error:14094412:SSL routines:ssl3_read_bytes:sslv3 alert bad certificate
```

**Verificação**:
```bash
# Verificar validade do certificado
openssl x509 -in nginx/certs/cliente-*.crt -text -noout | grep -A2 "Validity"

# Verificar se CA é válida
openssl verify -CAfile nginx/certs/ca.crt nginx/certs/cliente-*.crt
```

**Solução**: Regenerar certificados
```bash
cd nginx/certs
./gerar_certificados.sh
# Rebuild e redeploy do Nginx
```

#### 5. Docker Build Falha

**Sintoma**: Erro durante build das imagens
```bash
ERROR: failed to solve: process "/bin/sh -c ..." didn't complete successfully
```

**Verificações**:
```bash
# Verificar Docker Desktop rodando
docker info

# Verificar context do WSL
docker context list

# Limpar cache do Docker
docker system prune -a
```

#### 6. Deploy Script Falha

**Sintoma**: Erro no PowerShell script
```powershell
aws : O termo 'aws' não é reconhecido
```

**Solução**:
```powershell
# Instalar AWS CLI no Windows
# Configurar credenciais
aws configure
# Verificar instalação
aws sts get-caller-identity
```

### 🔧 Comandos de Debug Essenciais

#### Verificar Status Geral
```bash
# Status dos serviços ECS
aws ecs describe-services --cluster [SEU_PROJETO]-cluster --services [SEU_PROJETO]-api-service teste-api-nginx-service

# Status do NLB
aws elbv2 describe-load-balancers --names teste-api-nlb

# Status dos Target Groups
aws elbv2 describe-target-health --target-group-arn TARGET_GROUP_ARN
```

#### Logs em Tempo Real
```bash
# Seguir logs da API
aws logs tail "/ecs/teste-api/api" --follow

# Seguir logs do Nginx
aws logs tail "/ecs/teste-api/nginx" --follow

# Filtrar apenas erros
aws logs filter-log-events --log-group-name "/ecs/teste-api/nginx" --filter-pattern "ERROR"
```

#### Teste de Conectividade
```bash
# Teste SSL básico
openssl s_client -connect nlb-dns:443 -servername api.bodyharmony.life

# Teste com certificado cliente
openssl s_client -connect nlb-dns:443 -cert client.crt -key client.key

# Teste curl com debug
curl -k -v --cert client.crt --key client.key https://nlb-dns/api/webhook
```

---

## 📞 Suporte e Contatos

### 📋 Informações do Projeto

- **Ambiente**: AWS us-east-2
- **Projeto**: teste-api
- **Load Balancer**: teste-api-nlb-d8cc496564454ef5.elb.us-east-2.amazonaws.com
- **Domínio**: api.bodyharmony.life
- **ECS Cluster**: teste-api-cluster

### 🔗 Links Úteis

- [AWS ECS Console](https://console.aws.amazon.com/ecs/)
- [CloudWatch Logs](https://console.aws.amazon.com/cloudwatch/home#logsV2:)
- [ECR Repositories](https://console.aws.amazon.com/ecr/repositories)
- [Load Balancers](https://console.aws.amazon.com/ec2/v2/home#LoadBalancers:)
