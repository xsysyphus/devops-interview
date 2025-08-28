# Guia Cronológico Completo: Do Início ao Fim

Este é o guia definitivo e completo para a resolução do desafio. Siga estes passos na ordem exata para configurar, implantar e testar a solução.

---

## **FASE 1: Pré-requisitos e Configuração Inicial do Ambiente**

**Objetivo:** Preparar sua conta da AWS e sua máquina local.

### **Passo 1.1: Preparar a Conta da AWS (Ações no Console)**

#### **1.1.1: Criar um Usuário e Política de Permissões no IAM**

Este usuário terá chaves de acesso e permissões específicas para o Terraform e o GitHub Actions.

1.  **Acesse o serviço IAM** no Console da AWS.
2.  **Crie uma Política Customizada:**
    *   No menu à esquerda, clique em **Policies** -> **Create policy**.
    *   Selecione a aba **JSON**.
    *   Apague o conteúdo existente e cole o JSON abaixo. Ele contém todas as permissões exatas que o Terraform precisa para este projeto.
        ```json
            {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": [
                    "ec2:*",
                    "ecr:*",
                    "iam:CreateRole",
                    "iam:GetRole",
                    "iam:AttachRolePolicy",
                    "iam:PassRole",
                    "iam:DeleteRole",
                    "iam:DetachRolePolicy",
                    "iam:CreateServiceLinkedRole",
                    "iam:ListRolePolicies",
                    "iam:ListAttachedRolePolicies",
                    "iam:ListInstanceProfilesForRole",
                    "logs:*",
                    "ecs:*",
                    "servicediscovery:*",
                    "elasticloadbalancing:*",
                    "wafv2:*",
                    "route53:*",
                    "cloudwatch:PutDashboard",
                    "cloudwatch:DeleteDashboards",
                    "cloudwatch:GetDashboard"
                ],
                "Resource": "*"
            }
        ]
    }
        ```
    *   Clique em **Next: Tags**, depois **Next: Review**.
    *   **Name:** `DevOpsChallengeCompletePolicy`.
    *   Clique em **Create policy**.
3.  **Crie o Usuário:**
    *   No menu à esquerda, clique em **Users** -> **Create user**.
    *   **User name:** `devops-challenge-user`.
    *   Clique em **Next**.
4.  **Anexe a Política ao Usuário:**
    *   Selecione **Attach policies directly**.
    *   Na barra de busca, procure pela política `DevOpsChallengeCompletePolicy`.
    *   Marque a caixa de seleção ao lado dela.
    *   Clique em **Next** e depois em **Create user**.
5.  **Crie e salve as chaves de acesso:**
    *   Na lista de usuários, clique no nome `devops-challenge-user`.
    *   Vá para a aba **Security credentials** -> **Create access key**.
    *   Selecione **Command Line Interface (CLI)**, marque a confirmação e clique em **Next**.
    *   Clique em **Create access key**.
    *   **MUITO IMPORTANTE:** Copie e guarde a **Access key ID** e a **Secret access key** em um local seguro.

#### **1.1.2: Obter um Domínio (Opcional, mas Recomendado)**

Para obter um certificado SSL validado (e evitar erros de segurança no navegador/curl), você precisa de um nome de domínio. Se você não tem um, pode registrar um de forma muito barata para testes.

1.  **Vá para um registrador de domínios** como [Freenom](https://www.freenom.com/pt/index.html) (oferece domínios gratuitos de teste como .tk, .ml) ou [Namecheap](https://www.namecheap.com/) (domínios .xyz ou .club costumam custar ~$1 por ano).
2.  **Registre um domínio.** Você não precisa de hospedagem, apenas o registro do nome.

#### **1.1.3: Obter o Certificado SSL/TLS no ACM**

1.  **Acesse o serviço ACM:** Na barra de busca, digite `Certificate Manager`.
2.  **Mude para a região correta:** `us-east-1` (N. Virginia) é geralmente a melhor escolha para certificados, mesmo que sua infraestrutura esteja em outra região.
3.  **Solicite um certificado:**
    *   Clique em **Request a certificate** -> **Request a public certificate**.
    *   **Domain name:** Insira `bodyharmony.life` e clique em "Add another name to this certificate" e insira `*.bodyharmony.life`. Isso criará um certificado wildcard que cobre todos os subdomínios (como `api.bodyharmony.life`).
    *   **Validation method:** Deixe **DNS validation** selecionado e clique em **Request**.
4.  **Valide a propriedade do domínio:**
    *   O status do certificado ficará "Pending validation".
    *   Na seção **Domains**, copie o **CNAME name** e o **CNAME value**.
    *   Vá ao painel de controle do seu registrador de domínios e adicione um novo registro do tipo `CNAME` com esses valores. Isso prova para a AWS que você é o dono do domínio.
5.  **Aguarde a emissão:** O status mudará para **Issued** após alguns minutos/horas.
6.  **Copie o ARN:**
    *   Clique no ID do seu certificado. Na página de detalhes, copie o **ARN**. Guarde-o para usar no `terraform/variables.tf`.

### **Passo 1.2: Configurar a AWS CLI Localmente**

1.  Abra seu terminal.
2.  Execute o comando:
    ```bash
    aws configure
    ```
3.  Insira as credenciais que você salvou no Passo 1.1.1.

### **Passo 1.3: Criar a Service-Linked Role para o ECS (Pré-requisito)**

Contas AWS novas ou com permissões restritas podem precisar que a "role de serviço" do ECS seja criada manualmente antes do Terraform ser executado.

1.  Abra seu terminal.
2.  Execute o seguinte comando. Ele só precisa ser executado uma vez por conta.
    ```bash
    aws iam create-service-linked-role --aws-service-name ecs.amazonaws.com
    ```
    *Se o comando retornar um erro dizendo que a role "já existe", isso é normal e pode ser ignorado.*

---

## **FASE 2: Validação e Customização dos Arquivos de Projeto**

**Objetivo:** Garantir que os arquivos do projeto estão corretos e preencher os valores customizáveis.

### **Passo 2.1: Validar Arquivos Existentes**
Os arquivos de configuração do Terraform, Nginx e GitHub Actions já foram criados. Esta fase consiste em revisá-los e customizá-los.

### **Passo 2.2: Customizar Variáveis do Terraform**

1.  **Abra o arquivo `terraform/variables.tf`**.
2.  Substitua o seguinte placeholder:
    *   `[NOME_DO_MEU_PROJETO]`: Por um nome único para o projeto (ex: `"fidencio-challenge"`).
    
    **Nota:** A região da AWS e o ARN do certificado já foram preenchidos para você. Os CIDRs da VPC e o número de instâncias também já possuem valores padrão adequados.

---

## **FASE 3: Provisionamento da Infraestrutura**

**Objetivo:** Rodar o Terraform para criar a infraestrutura na AWS e, em seguida, gerar os certificados mTLS. A infraestrutura inclui a rede (VPC), segurança (Security Groups, WAF), a plataforma de contêineres (ECR, ECS) e um dashboard de monitoramento (CloudWatch).

### **Passo 3.1: Executar o Terraform**

1.  **Navegue até a pasta `terraform/`** no seu terminal.
2.  **Inicialize o Terraform:**
    ```bash
    terraform init
    ```
3.  **Aplique a configuração:**
    ```bash
    terraform apply
    ```
4.  Digite `yes` quando solicitado para confirmar.
5.  Ao final, o Terraform mostrará o `alb_dns_name`. **Copie e guarde este valor.**

### **Passo 3.2: Gerar Certificados e Configurar Nginx**

1.  **Edite o arquivo `nginx/nginx.conf`:**
    *   A linha `server_name` já está configurada para `api.bodyharmony.life`.
    *   Na linha `proxy_pass`, substitua `[NOME_DO_MEU_PROJETO]` pelo mesmo nome que você usou no `variables.tf` (ex: `teste-api`).
2.  **Gere os certificados com o script automatizado:**
    *   No terminal, navegue até a pasta `nginx/`.
    *   Torne o script executável:
        ```bash
        chmod +x gerar_certificados.sh
        ```
    *   Execute o script, passando o seu domínio como argumento:
        ```bash
        ./gerar_certificados.sh api.bodyharmony.life
        ```
    *   O script irá criar a pasta `certs` e gerar todos os arquivos necessários automaticamente.

---

## **FASE 4: Deploy e Teste via CI/CD**

**Objetivo:** Configurar os segredos no GitHub, enviar o código para acionar o pipeline e testar a aplicação.

### **Passo 4.1: Configurar Segredos no Repositório GitHub**

Os "Secrets" são a maneira segura de passar informações sensíveis (como credenciais e nomes de recursos) para o seu pipeline de CI/CD.

1.  **Vá para as Configurações do seu Repositório no GitHub:**
    *   Abra a página do seu projeto no site do GitHub.
    *   Clique na aba **"Settings"**.
    *   No menu à esquerda, expanda **"Secrets and variables"** e clique em **"Actions"**.

2.  **Adicione os Seguintes Secrets:**
    *   Clique em **"New repository secret"** para cada item da lista abaixo. O nome do secret deve ser **exatamente** como mostrado.

    ---
    *   **Nome:** `AWS_ACCESS_KEY_ID`
        *   **Valor:** A chave de acesso que você salvou na **Fase 1.1.1**.

    *   **Nome:** `AWS_SECRET_ACCESS_KEY`
        *   **Valor:** A chave secreta correspondente que você salvou na **Fase 1.1.1**.

    *   **Nome:** `AWS_REGION`
        *   **Valor:** `us-east-2`

    *   **Nome:** `ECR_REGISTRY`
        *   **Valor:** `693014165328.dkr.ecr.us-east-2.amazonaws.com`

    *   **Nome:** `ECR_REPOSITORY_API`
        *   **Valor:** `teste-api-api`

    *   **Nome:** `ECR_REPOSITORY_NGINX`
        *   **Valor:** `teste-api-nginx`

    *   **Nome:** `ECS_CLUSTER_NAME`
        *   **Valor:** `teste-api-cluster`

    *   **Nome:** `ECS_SERVICE_API`
        *   **Valor:** `teste-api-api-service`

    *   **Nome:** `ECS_SERVICE_NGINX`
        *   **Valor:** `teste-api-nginx-service`

    *   **Nome:** `ECS_TASK_DEFINITION_API`
        *   **Valor:** `teste-api-api-task`
        *   **Como confirmar:** Vá ao Console da AWS -> ECS -> Task Definitions. O nome da "família" estará listado.

    *   **Nome:** `ECS_TASK_DEFINITION_NGINX`
        *   **Valor:** `teste-api-nginx-task`

    *   **Nome:** `CONTAINER_NAME_API`
        *   **Valor:** `teste-api-api-container`
        *   **Como confirmar:** Clique na Task Definition `teste-api-api-task` -> clique na última revisão -> desça até "Container details".

    *   **Nome:** `CONTAINER_NAME_NGINX`
        *   **Valor:** `teste-api-nginx-container`
    ---

### **Passo 4.2: Enviar Código e Acionar Pipeline**

1.  No terminal, na raiz do projeto, execute:
    ```bash
    git add .
    git commit -m "Finaliza configuração para deploy inicial"
    git push origin main
    ```
2.  Vá para a aba `Actions` no GitHub e acompanhe a execução do workflow. Espere até que ele termine com sucesso.

### **Passo 4.3: Testar a Aplicação**

1.  **Crie o Registro DNS:** Antes de testar, vá ao painel de controle do seu domínio (`bodyharmony.life`) e crie um novo registro do tipo `CNAME`.
    *   **Nome/Host:** `api`
    *   **Valor/Aponta para:** O `alb_dns_name` que o Terraform forneceu.
    *   Pode levar alguns minutos para o DNS propagar.

2.  **Execute os Testes:**
    ```bash
    curl -k https://[DNS_DO_SEU_ALB_AQUI]/health
    ```
    *Espera-se a resposta: `OK`*

3.  **Teste 2: Webhook sem Certificado (deve FALHAR)**
    ```bash
    curl -k -v -X POST https://[DNS_DO_SEU_ALB_AQUI]/api/webhook
    ```
    *Espera-se um erro do Nginx relacionado à ausência de certificado SSL.*

4.  **Teste 3: Webhook com Certificado (deve funcionar)**
    ```bash
    curl -X POST https://api.bodyharmony.life/api/webhook \
      --cert ./nginx/certs/client.crt \
      --key ./nginx/certs/client.key \
      -H "Content-Type: application/json" \
      -d '{"event": "order_created", "data": {"order_id": "12345"}}'
    ```
    *Espera-se a resposta da API incluindo informações do cliente e timestamp.*

---

## **FASE 5: Troubleshooting**

**Problemas Comuns e Soluções:**

1.  **Erros de "ResourceAlreadyExistsException" ou "EntityAlreadyExists":**
    *   **Causa:** Isso acontece se um `terraform apply` anterior falhou no meio do caminho, deixando recursos órfãos na sua conta AWS que o `terraform destroy` não conseguiu limpar.
    *   **Solução Definitiva (Limpeza Manual):**
        1.  **Delete os Repositórios ECR:** Vá para o serviço ECR, selecione os repositórios (`-api`, `-nginx`) e delete-os.
        2.  **Delete os Log Groups:** Vá para CloudWatch > Log Groups, selecione os logs (`/ecs/.../api`, `/ecs/.../nginx`) e delete-os.
        3.  **Delete a IAM Role:** Vá para IAM > Roles, encontre a role (`-ecs-task-execution-role`) e delete-a.
        4.  **Delete a VPC:** Vá para o serviço VPC, encontre a VPC do projeto e delete-a. Isso deve remover a maioria dos recursos de rede. Libere também qualquer Elastic IP.
        5.  **Limpe o Estado Local:** Na sua pasta `terraform/`, delete os arquivos `terraform.tfstate` e `terraform.tfstate.backup`.
        6.  **Tente o `terraform apply` novamente.** O ambiente estará 100% limpo.

2.  **Erro 502 Bad Gateway no ALB**
    - Verifique se os serviços ECS estão rodando: AWS Console > ECS > Cluster > Services
    - Verifique os logs no CloudWatch: `/ecs/[project-name]/nginx` e `/ecs/[project-name]/api`
    - Confirme que o health check do Target Group está passando

3.  **Erro "No required SSL certificate was sent"**
    - Isso é esperado quando não se fornece certificado de cliente
    - Se ocorrer mesmo com certificado, verifique se o arquivo está no caminho correto

4.  **Erro ao fazer push das imagens no GitHub Actions**
    - Verifique se os secrets do GitHub estão corretos
    - Confirme que o usuário IAM tem permissões para o ECR

5.  **Serviços ECS não iniciam**
    - Verifique se as imagens foram enviadas ao ECR com sucesso
    - Confirme que as subnets privadas têm acesso à internet via NAT Gateway
    - Verifique os Security Groups

---

## **FASE 6: Limpeza (Opcional)**

**Objetivo:** Destruir todos os recursos da AWS para não gerar custos.

1.  No terminal, na pasta `terraform/`, execute:
    ```bash
    terraform destroy
    ```
2.  Digite `yes` para confirmar.


