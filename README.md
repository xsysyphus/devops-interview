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
- [ ] API acessível via HTTPS
- [ ] mTLS rejeitando requests sem certificado
- [ ] mTLS aceitando requests com certificado válido
- [ ] Pipeline executando sem erros
- [ ] Documentação completa
- [ ] Testes básicos funcionando

---

**Boa sorte! 🚀**

*Este desafio simula um cenário real de implementação de APIs seguras em produção. Demonstre suas habilidades técnicas e capacidade de documentar soluções complexas.*
