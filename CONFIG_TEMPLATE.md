# Template de Configuração - DevOps Interview

Este arquivo contém todos os valores que você precisa personalizar para colocar o projeto em execução na sua conta AWS. O fluxo de trabalho principal utiliza o pipeline de CI/CD do GitHub Actions.

## 1. Configurações do Terraform

Edite o arquivo `terraform/variables.tf` com os valores da sua conta.

### Variáveis Obrigatórias:
```hcl
variable "aws_region" {
  default = "us-east-1"        # ← Sua região AWS preferida
}

variable "project_name" {
  default = "minha-api"        # ← Nome do seu projeto (sem espaços, só letras, números e hífens)
}
```

## 2. Configurações do Pipeline (GitHub Actions)

Para que o pipeline de CI/CD (`.github/workflows/deploy.yml`) funcione, você precisa configurar a autenticação segura (OIDC) entre o GitHub e a AWS.

Siga as instruções detalhadas nos comentários do arquivo `deploy.yml` para criar:
1.  Um **Provedor de Identidade OIDC** no IAM da AWS.
2.  Uma **Role no IAM** para o GitHub Actions assumir.

Depois de criar a role, adicione os seguintes **Secrets** no seu repositório do GitHub (`Settings > Secrets and variables > Actions`):

-   `AWS_REGION`: A região AWS que você configurou no Terraform (ex: `us-east-1`).
-   `AWS_IAM_ROLE_ARN`: O ARN da role do IAM que você criou (ex: `arn:aws:iam::123456789012:role/GitHubActions_ECS_DeployRole`).

## 3. Configuração do Nginx e Certificados

### Nginx (`nginx/nginx.conf`):
```nginx
server_name api.seudominio.com;  # ← Seu domínio OU use _ para aceitar qualquer host

# Na linha do proxy_pass:
proxy_pass http://api.minha-api.local:5000;  # ← api.[project_name].local:5000
```

### Certificados (`nginx/certs/gerar_certificados.sh`):
```bash
COMMON_NAME_SERVER="api.seudominio.com"  # ← Mesmo domínio do nginx.conf OU o DNS do NLB
```

## 4. Passo a Passo de Configuração

### **Passo 1: Provisionar a Infraestrutura com Terraform**
```bash
# Navegue até a pasta do Terraform
cd terraform

# Edite o arquivo variables.tf com seus valores
# ...

# Inicialize, planeje e aplique
terraform init
terraform plan
terraform apply --auto-approve
```

### **Passo 2: Obter o DNS do Load Balancer**
Após o `terraform apply` ser concluído, anote o DNS do NLB.
```bash
terraform output alb_dns_name
```

### **Passo 3: Gerar os Certificados SSL/mTLS**
Use o DNS do NLB obtido no passo anterior como `COMMON_NAME_SERVER`.
```bash
# Edite o COMMON_NAME_SERVER em nginx/certs/gerar_certificados.sh
# ...

# Navegue até a pasta e execute o script
cd ../nginx/certs
bash gerar_certificados.sh
```
**Importante:** Após gerar os certificados, a imagem do Nginx precisa ser reconstruída para incluí-los.

### **Passo 4: Configurar os Secrets do GitHub Actions**
Siga as instruções da Seção 2 deste guia para configurar os secrets `AWS_REGION` e `AWS_IAM_ROLE_ARN` no seu repositório.

### **Passo 5: Acionar o Pipeline**
Faça um `git commit` e `git push` das suas alterações (incluindo os novos certificados) para a branch `main`.
```bash
git add .
git commit -m "Configuração inicial e geração de certificados"
git push origin main
```
O pipeline do GitHub Actions será acionado automaticamente, construirá as imagens e fará o deploy na infraestrutura que você provisionou.

### **Passo 6: Testar a API**
```bash
# Use o DNS do NLB para testar
NLB_DNS=$(terraform -chdir=./terraform output -raw alb_dns_name)

# Health check (deve retornar 200)
curl -k https://$NLB_DNS/health

# API sem certificado (deve retornar 403)
curl -k https://$NLB_DNS/api/webhook

# API com certificado (deve retornar 200)
curl -k --cert ./nginx/certs/cliente-*.crt \
  --key ./nginx/certs/cliente-*.key \
  https://$NLB_DNS/api/webhook \
  -H "Content-Type: application/json" \
  -d '{"test": "data"}'
```

## 5. Informações Importantes

-   **Região AWS**: Use sempre a mesma região no Terraform e nos secrets do GitHub.
-   **Certificados**: Os certificados gerados são para fins de teste. Em um ambiente de produção, utilize uma infraestrutura de PKI gerenciada.
-   **Credenciais**: Nunca commite credenciais estáticas da AWS no Git. O método OIDC utilizado é a prática recomendada.
