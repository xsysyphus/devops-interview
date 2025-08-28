# VALIDAÇÃO FINAL - Guia de Testes

Este arquivo contém todos os testes necessários para validar se sua implementação está funcionando corretamente.

## PRÉ-REQUISITOS

Antes de executar os testes, certifique-se de que:

1. **Terraform aplicado** com sucesso (`terraform apply`)
2. **Certificados gerados** (executar `nginx/certs/gerar_certificados.sh`)
3. **Deploy realizado** (executar `deploy.ps1`)
4. **DNS configurado** (se usando domínio customizado)

## TESTES OBRIGATÓRIOS

### **Teste 1: Health Check (Público)**
```bash
curl -k https://[SEU_NLB_DNS]/health
```
**Resultado Esperado:** `200 OK` com resposta `"OK"`

### **Teste 2: API sem Certificado (Deve Falhar)**
```bash
curl -k https://[SEU_NLB_DNS]/api/webhook
```
**Resultado Esperado:** `403 Forbidden` (mTLS bloqueou)

### **Teste 3: API com Certificado (Deve Funcionar)**
```bash
curl -k --cert ./nginx/certs/cliente-[TIMESTAMP].crt \
  --key ./nginx/certs/cliente-[TIMESTAMP].key \
  https://[SEU_NLB_DNS]/api/webhook \
  -H "Content-Type: application/json" \
  -d '{"test": "data"}'
```
**Resultado Esperado:** `200 OK` com resposta JSON da API

### **Teste 4: Endpoint Raiz da API**
```bash
curl -k --cert ./nginx/certs/cliente-[TIMESTAMP].crt \
  --key ./nginx/certs/cliente-[TIMESTAMP].key \
  https://[SEU_NLB_DNS]/
```
**Resultado Esperado:** `200 OK` com informações da API

## TESTES ADICIONAIS

### **Teste 5: Verificar SSL/TLS**
```bash
openssl s_client -connect [SEU_NLB_DNS]:443 -servername [SEU_DOMINIO] | head -20
```
**Verificar:** Handshake SSL bem-sucedido

### **Teste 6: Verificar Certificado Cliente**
```bash
openssl verify -CAfile ./nginx/certs/ca.crt ./nginx/certs/cliente-[TIMESTAMP].crt
```
**Resultado Esperado:** `OK`

### **Teste 7: Performance**
```bash
curl -k --cert ./nginx/certs/cliente-[TIMESTAMP].crt \
  --key ./nginx/certs/cliente-[TIMESTAMP].key \
  https://[SEU_NLB_DNS]/health \
  -w "Time: %{time_total}s\n"
```
**Meta:** Tempo de resposta < 2 segundos

## RESULTADOS ESPERADOS

| **Teste** | **Comando** | **HTTP Code** | **Status** |
|-----------|-------------|---------------|------------|
| Health Check | `curl /health` | `200` | SUCESSO |
| API sem cert | `curl /api/webhook` | `403` | SUCESSO (mTLS bloqueou) |
| API com cert | `curl --cert --key /api/webhook` | `200` | SUCESSO |
| Endpoint raiz | `curl --cert --key /` | `200` | SUCESSO |

## TROUBLESHOOTING

### **Erro 502/504 (Bad Gateway/Timeout)**
**Possíveis Causas:**
- Serviços ECS não estão rodando
- Service Discovery com problemas
- API não está respondendo

**Soluções:**
```bash
# Verificar serviços ECS
aws ecs list-tasks --cluster [SEU_PROJETO]-cluster --region [SUA_REGIAO]

# Verificar logs
aws logs tail "/ecs/[SEU_PROJETO]/nginx" --follow --region [SUA_REGIAO]
aws logs tail "/ecs/[SEU_PROJETO]/api" --follow --region [SUA_REGIAO]

# Forçar redeploy
aws ecs update-service --cluster [SEU_PROJETO]-cluster --service [SEU_PROJETO]-nginx-service --force-new-deployment --region [SUA_REGIAO]
```

### **Erro 403 para /health**
**Causa:** Configuração incorreta do mTLS no Nginx

**Solução:** Verificar `nginx.conf`:
```nginx
location /health {
    # Sem ssl_verify_client on aqui
    return 200 "OK";
}
```

### **Certificado Inválido**
**Causa:** Certificados mal gerados ou expirados

**Solução:**
```bash
# Regenerar certificados
cd nginx/certs
bash gerar_certificados.sh

# Rebuild Nginx
docker build -t [SEU_PROJETO]-nginx ./nginx/
# ... push e redeploy
```

### **DNS não resolve**
**Possíveis Causas:**
- DNS não configurado corretamente
- Aguardar propagação DNS

**Verificações:**
```bash
# Verificar resolução DNS
nslookup [SEU_DOMINIO]
dig [SEU_DOMINIO]

# Usar diretamente o DNS do NLB se necessário
terraform output alb_dns_name
```

## CHECKLIST FINAL

- [ ] **Teste 1** (Health Check): `200 OK`
- [ ] **Teste 2** (API sem cert): `403 Forbidden`  
- [ ] **Teste 3** (API com cert): `200 OK`
- [ ] **Teste 4** (Endpoint raiz): `200 OK`
- [ ] **Performance**: Tempo < 2s
- [ ] **SSL/TLS**: Handshake bem-sucedido
- [ ] **Certificados**: Válidos e verificados
- [ ] **Logs**: Sem erros críticos
- [ ] **Monitoramento**: CloudWatch funcionando
- [ ] **Documentação**: Completa e atualizada