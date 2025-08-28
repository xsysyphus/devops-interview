# Template de Configuração - DevOps Interview

Este arquivo contém todos os valores que você precisa personalizar para usar este projeto em sua própria conta AWS.

## 1. Configurações do Terraform

Edite o arquivo `terraform/variables.tf` e preencha:

### Variáveis Obrigatórias:
```hcl
variable "aws_region" {
  default = "us-east-1"        # ← Sua região AWS preferida
}

variable "project_name" {
  default = "minha-api"        # ← Nome do seu projeto (sem espaços, só letras, números e hífens)
}
```

### Variáveis Opcionais (podem manter os padrões):
```hcl
variable "vpc_cidr" {
  default = "10.0.0.0/16"      # ← CIDR da sua VPC (mantenha se não souber)
}

variable "acm_certificate_arn" {
  default = ""                 # ← ARN do certificado ACM (apenas se tiver domínio customizado)
}
```

## 2. Scripts de Deploy

### Para `deploy.ps1`:
```powershell
$awsRegion = "us-east-1"                           # ← Mesma região do Terraform
$ecrRegistryUrl = "123456789012.dkr.ecr.us-east-1.amazonaws.com"  # ← Obtido com: terraform output ecr_registry_url
$ecrRepositoryApi = "minha-api-api"                # ← [project_name]-api
$ecrRepositoryNginx = "minha-api-nginx"            # ← [project_name]-nginx
$ecsClusterName = "minha-api-cluster"              # ← [project_name]-cluster
$ecsServiceApi = "minha-api-api-service"           # ← [project_name]-api-service
$ecsServiceNginx = "minha-api-nginx-service"       # ← [project_name]-nginx-service
```

### Para `deploy_nginx_only.ps1`:
```powershell
$awsRegion = "us-east-1"                           # ← Mesma região
$ecrRegistry = "123456789012.dkr.ecr.us-east-1.amazonaws.com"     # ← Mesma URL do ECR
$ecsCluster = "minha-api-cluster"                  # ← Mesmo cluster
$nginxService = "minha-api-nginx-service"          # ← Mesmo serviço Nginx
$nginxRepo = "minha-api-nginx"                     # ← Mesmo repositório Nginx
```

## 3. Configuração do Nginx

Edite `nginx/nginx.conf`:

```nginx
server_name api.seudominio.com;  # ← Seu domínio OU use _ para aceitar qualquer host

# Na linha do proxy_pass:
proxy_pass http://api.minha-api.local:5000;  # ← api.[project_name].local:5000
```

## 4. Certificados SSL/mTLS

Edite `nginx/certs/gerar_certificados.sh`:

```bash
COMMON_NAME_SERVER="api.seudominio.com"  # ← Mesmo domínio do nginx.conf OU seu IP público
```

## 5. Passo a Passo de Configuração

### **Passo 1: Configure as variáveis do Terraform**
```bash
cd terraform
# Edite variables.tf com seus valores
terraform init
terraform plan    # Revise o que será criado
terraform apply   # Confirme com 'yes'
```

### **Passo 2: Obtenha os outputs do Terraform**
```bash
terraform output
# Anote os valores:
# - ecr_registry_url
# - alb_dns_name (DNS do seu Load Balancer)
```

### **Passo 3: Gere os certificados SSL/mTLS**
```bash
cd ../nginx/certs
# No Windows/PowerShell: wsl bash gerar_certificados.sh
# No Linux/Mac: bash gerar_certificados.sh
```

### **Passo 4: Configure os scripts de deploy**
- Edite `deploy.ps1` com os valores obtidos no Passo 2
- Edite `deploy_nginx_only.ps1` com os mesmos valores

### **Passo 5: Configure suas credenciais AWS**
```bash
aws configure
# AWS Access Key ID: [SUA_ACCESS_KEY]
# AWS Secret Access Key: [SUA_SECRET_KEY]
# Default region: [SUA_REGIAO]
# Default output format: json
```

### **Passo 6: Faça o primeiro deploy**
```powershell
# No PowerShell (Windows)
./deploy.ps1
```

### **Passo 7: Teste sua API**
```bash
# Health check (deve retornar 200)
curl -k https://[SEU_NLB_DNS]/health

# API sem certificado (deve retornar 403)
curl -k https://[SEU_NLB_DNS]/api/webhook

# API com certificado (deve retornar 200)
curl -k --cert ./nginx/certs/cliente-[TIMESTAMP].crt \
  --key ./nginx/certs/cliente-[TIMESTAMP].key \
  https://[SEU_NLB_DNS]/api/webhook \
  -H "Content-Type: application/json" \
  -d '{"test": "data"}'
```

## 6. Valores de Exemplo Completos

### Exemplo com projeto chamado "devops-api" na região "us-west-2":

**terraform/variables.tf:**
```hcl
variable "aws_region" {
  default = "us-west-2"
}

variable "project_name" {
  default = "devops-api"
}
```

**deploy.ps1:**
```powershell
$awsRegion = "us-west-2"
$ecrRegistryUrl = "123456789012.dkr.ecr.us-west-2.amazonaws.com"
$ecrRepositoryApi = "devops-api-api"
$ecrRepositoryNginx = "devops-api-nginx"
$ecsClusterName = "devops-api-cluster"
$ecsServiceApi = "devops-api-api-service"
$ecsServiceNginx = "devops-api-nginx-service"
```

**nginx/nginx.conf:**
```nginx
server_name _;  # Aceita qualquer host (sem domínio customizado)
proxy_pass http://api.devops-api.local:5000;
```

**nginx/certs/gerar_certificados.sh:**
```bash
COMMON_NAME_SERVER="api.exemplo.com"  # Ou seu IP público
```

## Importante

1. **Região AWS**: Use sempre a mesma região em todos os arquivos
2. **Nome do Projeto**: Use apenas letras, números e hífens (sem espaços ou caracteres especiais)
3. **Domínio**: Se não tiver domínio próprio, use `_` no server_name do Nginx
4. **Certificados**: Mantenha os arquivos `.key` seguros e nunca os compartilhe
5. **Credenciais**: Nunca commite credenciais AWS no Git

## Troubleshooting

- **Terraform apply falha**: Verifique se suas credenciais AWS têm as permissões necessárias
- **Deploy falha**: Verifique se Docker Desktop está rodando
- **Teste 403**: Verifique se os certificados foram gerados corretamente
- **Teste 502/504**: Aguarde alguns minutos para os serviços subirem completamente

---

**Suporte**: Consulte `DOCUMENTACAO_IMPLEMENTACAO.md` para troubleshooting detalhado.
