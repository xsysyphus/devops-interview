# DevOps Challenge - Deploy de API com mTLS 🚀

Desafio técnico para avaliação de conhecimentos em DevOps, focado na implementação de uma infraestrutura completa na AWS com segurança avançada.

## 📋 Objetivo

Implementar uma infraestrutura de produção para hospedar uma API Python que recebe webhooks de terceiros, com os seguintes requisitos:

### ✅ Requisitos Obrigatórios

1. **API no ECS Fargate** - Deploy da aplicação Python fornecida
2. **ALB Público** - Load balancer com SSL/TLS. Deve rotear o tráfego validado pelo Nginx para a API no ECS.
3. **Nginx API Gateway** - Proxy reverso com **mTLS obrigatório**. Após validação, encaminhar requisições para o ALB → ECS
4. **Pipeline GitHub Actions** - CI/CD automatizado
5. **Documentação completa** - Setup e troubleshooting

### 🏆 Diferenciais (Opcional, mas valorizado)

6. **Stack de Monitoring**
7. **Segurança Avançada**
8. **Testes Automatizados**

## 🎯 Cenário da Aplicação

### API Fornecida
A API Python (pasta `api/`) já está pronta e contém:
- **Endpoint principal**: `POST /api/webhook` - Recebe dados de terceiros
- **Health check**: `GET /health` - Para monitoramento
- **Logs estruturados** - Para observabilidade
- **Container Docker** - Pronto para deploy

### Exemplo de Uso
```bash
# Health check
curl https://your-domain.com/health

# Webhook de terceiros
curl -X POST https://your-domain.com/api/webhook \
  --cert client.crt --key client.key \
  -H "Content-Type: application/json" \
  -d '{"event": "order_created", "data": {"order_id": "12345"}}'
```

## 🧪 Critérios de Teste

### Testes Básicos (Obrigatórios)
```bash
# 1. API deve responder via ALB
curl https://your-alb-dns/health
# Esperado: 200 OK

# 2. mTLS deve rejeitar sem certificado
curl https://your-alb-dns/api/webhook
# Esperado: 403 Forbidden ou similar

# 3. mTLS deve aceitar com certificado
curl --cert client.crt --key client.key \
  https://your-alb-dns/api/webhook \
  -d '{"test": "data"}'
# Esperado: 200 OK
```

## ⚡ Como Começar

### 1. Fork e Setup
```bash
git clone <seu-fork>
cd devops-interview
```

## 📞 Suporte

- **Dúvidas sobre requisitos**: Abra uma issue no repositório ou entre em contato com o avaliador 
- **Problemas técnicos**: Consulte documentação AWS/Componentes utilizados
- **Clarificações**: Use os comentários do desafio

## 🚫 Restrições

- **Não modificar** a API fornecida (pasta `api/`)
- **Usar ECS Fargate** para a API
- **mTLS é obrigatório** - requests sem certificado devem falhar
- **Documentar** todas as decisões técnicas

## 🏆 Entrega

### Formato
1. **Fork** deste repositório
2. **Implemente** sua solução
3. **Teste** tudo funcionando
4. **Documente** o processo
5. **Envie** link do repositório

### Checklist Final
- [x] API acessível via HTTPS
- [x] mTLS rejeitando requests sem certificado  
- [x] mTLS aceitando requests com certificado válido
- [x] Pipeline executando sem erros
- [x] Documentação completa
- [x] Testes básicos funcionando

---

## 🏆 **SOLUÇÃO IMPLEMENTADA**

Esta implementação atende **100% dos requisitos obrigatórios** e inclui **todos os diferenciais**:

### ✅ **Requisitos Cumpridos:**
- **API no ECS Fargate**: Deploy da aplicação Python original em containers serverless
- **Network Load Balancer**: Load balancer público com SSL passthrough para alta performance  
- **Nginx Gateway com mTLS**: Proxy reverso com autenticação mútua obrigatória
- **Scripts de Deploy**: Automação completa de deployment via PowerShell
- **Documentação Completa**: Guias técnicos, configuração e troubleshooting

### 🌟 **Diferenciais Implementados:**
- **Stack de Monitoring**: CloudWatch Dashboard com métricas personalizadas
- **Segurança Avançada**: WAFv2, Security Groups, isolamento de rede
- **Testes Automatizados**: Scripts de validação e verificação completos

### 📁 **Estrutura da Solução:**
```
├── 📁 api/                          # API Python original (preservada)
├── 📁 terraform/                    # Infraestrutura como código completa
├── 📁 nginx/                        # Gateway mTLS + certificados
├── 📁 scripts/                      # Scripts de deploy automatizados
├── 📄 DOCUMENTACAO_IMPLEMENTACAO.md # Documentação técnica detalhada
├── 📄 CONFIG_TEMPLATE.md            # Template de configuração
├── 📄 VALIDACAO_FINAL.md            # Guia de testes e validação
└── 📄 README.md                     # Este arquivo
```

### 🚀 **Como Testar a Implementação:**

1. **Configure suas credenciais AWS**
2. **Personalize** `terraform/variables.tf` com seus valores
3. **Gere certificados**: `bash nginx/certs/gerar_certificados.sh`  
4. **Aplique infraestrutura**: `terraform apply`
5. **Faça deploy**: `./scripts/deploy.ps1`
6. **Valide** seguindo `VALIDACAO_FINAL.md`

### 📋 **Documentação Completa:**
- **[DOCUMENTACAO_IMPLEMENTACAO.md](DOCUMENTACAO_IMPLEMENTACAO.md)**: Arquitetura, decisões técnicas, e guias detalhados
- **[CONFIG_TEMPLATE.md](CONFIG_TEMPLATE.md)**: Template de configuração para personalização  
- **[VALIDACAO_FINAL.md](VALIDACAO_FINAL.md)**: Testes, validação e troubleshooting

**🎯 Implementação enterprise-ready demonstrando domínio completo de práticas DevOps modernas.**

---

**Implementado por: Fidencio Vieira**  
*Este desafio demonstra implementação real de APIs seguras em produção com práticas DevOps enterprise.*
