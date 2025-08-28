# Apresentação do Projeto: API Segura com mTLS na AWS

## 1. Objetivo do Projeto

O objetivo deste projeto foi implementar uma infraestrutura de produção completa, segura e automatizada na AWS para hospedar uma API Python. A solução atende a requisitos críticos de segurança, como a autenticação mútua (mTLS) para comunicação com webhooks de terceiros, e implementa as melhores práticas de DevOps, como Infraestrutura como Código (IaC) e CI/CD.

---

## 2. Arquitetura da Solução

A arquitetura foi desenhada para garantir segurança em camadas, escalabilidade e alta disponibilidade.

```
Internet
   |
   | HTTPS (Porta 443) - [Certificado Público ACM]
   v
[ Application Load Balancer (ALB) ] --- (Localizado nas Sub-redes Públicas)
   |
   | HTTPS (Porta 443) - [Validação de Tráfego]
   v
[ Nginx Gateway Service (ECS Fargate) ] --- (Localizado nas Sub-redes Privadas)
   |  - Responsável pela terminação mTLS
   |  - Valida o certificado do cliente com a CA privada
   |
   | HTTP (Porta 8000) - [Comunicação Interna via Service Discovery]
   v
[ API Python Service (ECS Fargate) ] --- (Localizado nas Sub-redes Privadas)
   - Só aceita tráfego do Nginx Gateway
```

**Fluxo do Tráfego:**

1.  **Cliente Externo (Webhook):** Inicia uma requisição HTTPS para o domínio público, que aponta para o Application Load Balancer (ALB). O cliente **deve** apresentar seu certificado.
2.  **Application Load Balancer (ALB):** O ALB termina a conexão HTTPS usando um certificado público (gerenciado pelo ACM) e encaminha o tráfego para o serviço Nginx. Ele não valida o certificado do cliente; essa responsabilidade é delegada.
3.  **Nginx Gateway (ECS Fargate):** Este é o ponto central da segurança.
    *   Ele recebe a requisição do ALB.
    *   **Validação mTLS:** O Nginx verifica se o cliente apresentou um certificado e se este foi assinado pela nossa Autoridade Certificadora (CA) privada. Se a validação falhar, a conexão é imediatamente rejeitada.
    *   **Proxy Reverso:** Se a validação for bem-sucedida, o Nginx atua como um proxy reverso, encaminhando a requisição para o serviço da API Python.
4.  **API Python (ECS Fargate):** A aplicação recebe a requisição, que já foi validada e autenticada, e a processa. A comunicação entre o Nginx e a API ocorre de forma segura dentro da rede privada da VPC.

---

## 3. Tecnologias Utilizadas e Justificativas

A escolha de cada tecnologia foi baseada em critérios de eficiência, segurança, escalabilidade e conformidade com as melhores práticas de nuvem e DevOps.

| Tecnologia | Categoria | Justificativa da Escolha |
| :--- | :--- | :--- |
| **Terraform** | Infraestrutura como Código (IaC) | Permite a definição declarativa e versionável de toda a infraestrutura, garantindo consistência, reprodutibilidade e automação do provisionamento. Facilita a revisão e a colaboração. |
| **Docker** | Conteinerização | Empacota a aplicação e suas dependências em uma unidade isolada e portátil. Garante que o ambiente de execução seja consistente desde o desenvolvimento até a produção. |
| **Amazon ECS Fargate** | Orquestração de Contêineres | Plataforma *serverless* para rodar contêineres. Foi escolhida para abstrair o gerenciamento de servidores (instâncias EC2), permitindo focar apenas na aplicação. Simplifica a operação e o escalonamento. |
| **Nginx** | API Gateway & mTLS | Solução de proxy reverso extremamente performática e confiável. Foi escolhida por sua robusta capacidade de implementar a terminação mTLS, atuando como um gateway de segurança customizável para a API. |
| **GitHub Actions** | CI/CD | Solução de automação integrada ao GitHub. Foi escolhida para criar um pipeline de CI/CD que automatiza todo o ciclo de vida do deploy: build das imagens Docker, push para o registro e atualização dos serviços no ECS. |

---

## 4. Decisões de Implementação e Melhorias

Além dos requisitos básicos, foram tomadas decisões de arquitetura e implementadas melhorias para tornar a solução mais robusta, segura e production-ready.

### 4.1 Segurança Aprimorada
- **AWS WAF (Web Application Firewall)**: Uma camada de proteção foi adicionada ao ALB, utilizando regras gerenciadas pela AWS para bloquear ameaças comuns como SQL Injection, XSS e requisições de IPs com má reputação.
- **Configuração SSL/TLS Fortalecida**: Foram explicitamente configurados os protocolos TLS 1.2 e 1.3 com um conjunto de cifras seguras no Nginx, desabilitando versões mais antigas e vulneráveis.
- **Headers de Segurança**: Foram implementados headers adicionais (`X-Client-I-DN`, `X-Client-Serial`) para passar mais detalhes do certificado do cliente para a aplicação backend, permitindo auditoria e lógicas de autorização mais granulares.
- **Proteção de Chaves**: O arquivo `.gitignore` foi configurado para ignorar explicitamente chaves privadas e CSRs (`*.key`, `*.csr`), evitando o commit acidental de credenciais sensíveis.

### 4.2 Alta Disponibilidade e Resiliência
- **Múltiplas Instâncias**: A infraestrutura foi configurada para rodar com um mínimo de 2 instâncias para cada serviço (API e Nginx). Isso garante que não haja um ponto único de falha e permite atualizações sem downtime (*zero-downtime deployments*).
- **Distribuição entre AZs**: O Terraform distribui automaticamente as sub-redes e as tarefas do ECS entre múltiplas Zonas de Disponibilidade (AZs), garantindo resiliência a falhas em nível de datacenter.
- **Redirecionamento HTTP para HTTPS**: Foi adicionado um listener na porta 80 do ALB que redireciona permanentemente (301) todo o tráfego para HTTPS, garantindo que a comunicação seja sempre criptografada.

### 4.3 Otimizações de Performance
- **Timeouts de Proxy**: Foram configurados timeouts de conexão, envio e leitura (30s) no Nginx. Isso evita que requisições lentas prendam os workers e melhora a resiliência contra ataques de slowloris.
- **Otimizações de Rede do Nginx**: Foram habilitadas as diretivas `sendfile` e `tcp_nopush` para otimizar a entrega de respostas e o uso de pacotes de rede.

### 4.4 Observabilidade e Gerenciamento
- **Dashboard de Monitoramento no CloudWatch**: Foi criado um dashboard centralizado para a visualização das métricas mais importantes da aplicação em tempo real, incluindo a saúde do ALB, performance dos contêineres e requisições bloqueadas pelo WAF.
- **Retenção de Logs**: Os grupos de logs do CloudWatch foram configurados com uma política de retenção de 7 dias para controlar custos.
- **Tags de Ambiente**: Todos os recursos criados pelo Terraform são automaticamente marcados com uma tag `Environment`. Isso é fundamental para a governança de custos, automação e identificação de recursos em contas com múltiplos ambientes.
- **Outputs Terraform Expandidos**: Foram criados outputs adicionais para recursos chave (URLs do ECR, nomes dos serviços, etc.), facilitando a integração com outros sistemas de automação ou para depuração manual.

---

## 5. Detalhamento do Fluxo de CI/CD

O pipeline de automação é o coração da agilidade do projeto. Ele é acionado a cada `push` na branch `main` e executa os seguintes passos:

1.  **Checkout do Código:** O ambiente do workflow baixa a versão mais recente do código-fonte.
2.  **Autenticação na AWS:** Utiliza os segredos `AWS_ACCESS_KEY_ID` e `AWS_SECRET_ACCESS_KEY` para se autenticar de forma segura na conta da AWS.
3.  **Login no ECR:** Obtém credenciais de curta duração para permitir que o Docker se autentique no Amazon Elastic Container Registry (ECR).
4.  **Build & Push da Imagem da API:** Constrói a imagem Docker da API Python a partir do seu `Dockerfile`.
5.  **Build & Push da Imagem do Nginx:** Constrói a imagem Docker customizada do Nginx, que inclui a configuração e os certificados do servidor.
6.  **Atualização dos Serviços ECS:**
    *   Cria uma nova revisão da Task Definition para a API, apontando para a nova imagem no ECR.
    *   Cria uma nova revisão da Task Definition para o Nginx.
    *   Emite um comando de "force new deployment" para os serviços no ECS, que inicia um processo de atualização *rolling update*, substituindo as tarefas antigas pelas novas sem tempo de inatividade.

---

## 6. Conclusão

A solução implementada não apenas atende a todos os requisitos obrigatórios do desafio, mas também incorpora as melhores práticas de DevOps e cloud computing, resultando em uma infraestrutura production-ready que é:

- **Segura**: Com mTLS obrigatório e múltiplas camadas de segurança
- **Escalável**: Pronta para crescer conforme a demanda
- **Resiliente**: Com alta disponibilidade e distribuição entre AZs
- **Observável**: Com logs centralizados e métricas disponíveis
- **Automatizada**: Com pipeline CI/CD completo e IaC versionada

Esta implementação demonstra não apenas conhecimento técnico, mas também uma visão holística de como construir e operar sistemas modernos na nuvem.


.