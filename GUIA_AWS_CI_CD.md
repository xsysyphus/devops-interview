# Guia do Pipeline de CI/CD com AWS CodeCommit e CodePipeline

Este guia substitui o fluxo do GitHub Actions. Ele explica como usar o pipeline de CI/CD que foi criado dentro da sua própria conta AWS.

## Visão Geral do Novo Fluxo

1.  **Código-Fonte:** Em vez de enviar o código para o GitHub, você o enviará para um repositório Git privado no **AWS CodeCommit**, que o Terraform criou para você.
2.  **Gatilho:** O CodePipeline irá detectar automaticamente qualquer `push` na branch `main` deste novo repositório.
3.  **Build:** O **AWS CodeBuild** será acionado. Ele usará os arquivos `buildspec.yml` para construir as imagens Docker da API e do Nginx.
4.  **Armazenamento:** As imagens serão enviadas para os seus repositórios no **Amazon ECR**.
5.  **Deploy:** O CodePipeline irá forçar uma nova implantação dos seus serviços no **Amazon ECS**, que baixarão as novas imagens do ECR e as colocarão em execução sem downtime.

---

## **Passo 1: Aplicar a Nova Infraestrutura de CI/CD**

Se você ainda não o fez, aplique as mudanças do Terraform.

1.  No seu terminal, na pasta `terraform/`, execute:
    ```bash
    terraform apply
    ```
2.  Confirme com `yes`. O Terraform irá criar o repositório CodeCommit, os projetos CodeBuild e o CodePipeline.
3.  Nos outputs, procure pelo valor `codecommit_repo_clone_url_http`. Você precisará dele.

---

## **Passo 2: Configurar Credenciais do Git para o CodeCommit**

Para se conectar ao repositório no CodeCommit a partir do seu terminal, você não usa sua senha normal. Você precisa de credenciais específicas geradas pelo IAM.

1.  **Acesse o IAM no Console da AWS:**
    *   Vá para o serviço IAM e clique no seu usuário (`devops-challenge-user`).
2.  **Gere as Credenciais:**
    *   Vá para a aba **"Security credentials"**.
    *   Role para baixo até a seção **"HTTPS Git credentials for AWS CodeCommit"**.
    *   Clique em **"Generate credentials"**.
3.  **Salve as Credenciais:**
    *   O IAM irá gerar um **Username** e uma **Password**. **Copie e salve-os imediatamente** em um local seguro. Você não os verá novamente.

---

## **Passo 3: Enviar o Código para o CodeCommit**

1.  **Adicione o Novo Repositório Remoto:**
    *   No seu terminal, na raiz do projeto, execute o comando abaixo, substituindo a URL pelo output `codecommit_repo_clone_url_http` do Terraform.
        ```bash
        git remote add aws [URL_DO_CODECOMMIT_AQUI]
        ```
        *Exemplo: `git remote add aws https://git-codecommit.us-east-2.amazonaws.com/v1/repos/teste-api-repo`*

2.  **Faça o Push para o CodeCommit:**
    *   Execute o comando para enviar sua branch `main` para o novo repositório remoto `aws`:
        ```bash
        git push aws main
        ```
3.  **Autentique-se:**
    *   O Git irá pedir um `Username` e `Password`.
    *   **Username:** Cole o usuário que você gerou no Passo 2.
    *   **Password:** Cole a senha que você gerou no Passo 2.

O `push` será concluído com sucesso.

---

## **Passo 4: Acompanhar o Pipeline**

1.  **Acesse o CodePipeline no Console da AWS.**
2.  Clique no pipeline com o nome do seu projeto (ex: `teste-api-pipeline`).
3.  Você verá as etapas (Source, Build, Deploy) ficarem azuis (em progresso) e depois verdes (sucesso).

Quando a etapa de "Deploy" ficar verde, suas novas imagens estarão rodando no ECS. Você pode então prosseguir para os testes com `curl` como antes.
