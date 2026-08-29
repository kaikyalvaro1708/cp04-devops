# Portal Arcanjo SA

Portal institucional estático, empacotado em container e publicado em nuvem.

A aplicação roda em uma imagem `nginx:alpine`, é publicada no Docker Hub e no
Amazon ECR, e executa em uma instância EC2 provisionada por Terraform. Build,
publicação e deploy são automatizados por GitHub Actions.

## Estrutura

```
app/                     aplicação e Dockerfile
  index.html             conteúdo do portal
  Dockerfile             nginx:alpine servindo na porta 80
infra/                   Terraform: VPC, subnet, IGW, rotas, SG, ECR, IAM, EC2
  user_data.sh.tftpl     script executado pela EC2 no primeiro boot
.github/workflows/
  ci.yml                 em PR: lint do Dockerfile, build e smoke test
  cd.yml                 em main: push nos dois registries + deploy via SSM
```

## Arquitetura

A VPC (`10.0.0.0/24`) tem uma sub-rede pública com IPv4 automático, internet
gateway anexado e tabela de rotas com saída `0.0.0.0/0` associada à sub-rede. O
security group libera a porta 80 para a internet e a 22 apenas para o IP de quem
aplica o Terraform.

A instância é uma Amazon Linux 2023 que, no primeiro boot, instala o Docker,
grava um script de deploy em `/usr/local/bin/deploy.sh` e o executa. Esse mesmo
script é reutilizado pelo pipeline: o deploy não é um caminho paralelo, é o
mesmo código que rodou no boot.

O acesso ao ECR é feito por IAM role anexada à instância, sem credencial gravada
em disco.

## Pré-requisitos deste ambiente (Windows)

Duas particularidades desta máquina, já diagnosticadas:

**1. O Terraform do PATH é 32 bits e não funciona.** O binário em
`C:\Program Files\Terraform\terraform_1.13.4_windows_386` é `windows_386`; os
providers baixam mas crasham ao carregar o schema. Use o binário 64 bits em
`C:\Users\kaiki\bin\terraform.exe`, ou ajuste o PATH para priorizá-lo.

**2. O Avast intercepta TLS, inclusive em localhost.** Isso quebra duas coisas:

- O canal gRPC entre o Terraform e seus próprios plugins → exporte
  `TF_DISABLE_PLUGIN_TLS=1`. Isso desliga o mTLS apenas do canal local
  (127.0.0.1) entre processos do Terraform; **não** afeta o TLS com a AWS.
- O AWS CLI (Python) → falha com `CERTIFICATE_VERIFY_FAILED`. Contorno pontual:
  `--no-verify-ssl`. Solução definitiva: desativar a varredura HTTPS do Avast
  (Proteção → Proteções Principais → Proteção Web) ou exportar `AWS_CA_BUNDLE`
  apontando para um bundle que contenha a raiz do Avast.

O Terraform em si fala com a AWS normalmente, porque o Go usa o repositório de
certificados do Windows, onde a raiz do Avast já está instalada.

## Configurar a conta AWS

O provider aponta para um profile dedicado (`fiap`), separado de qualquer conta
de trabalho. Um `apply` acidental falha em vez de criar recursos na conta errada.

1. No console da conta: IAM → Users → Create user → policy `AdministratorAccess`.
2. Security credentials → Create access key → _Command Line Interface_.
3. Registre o profile:

```bash
aws configure --profile fiap
# região: us-east-1
```

4. Confirme a identidade antes de qualquer `apply`:

```bash
aws sts get-caller-identity --profile fiap --no-verify-ssl
```

## Provisionar

```bash
export TF_DISABLE_PLUGIN_TLS=1
cd infra
/c/Users/kaiki/bin/terraform.exe init
/c/Users/kaiki/bin/terraform.exe plan
/c/Users/kaiki/bin/terraform.exe apply
```

Outputs relevantes:

| Output               | Uso                                  |
| -------------------- | ------------------------------------ |
| `url_do_portal`      | URL pública do portal                |
| `ip_publico`         | IP público da instância              |
| `instance_id`        | Variável `EC2_INSTANCE_ID` no GitHub |
| `ecr_repository_url` | Variável `ECR_REPOSITORY` no GitHub  |
| `comando_ssh`        | Conexão SSH com a chave gerada       |

A chave SSH é gerada pelo Terraform em `infra/cp04-devops.pem`, ignorada pelo
git. Nunca commitar.

## Configurar o pipeline

**Secrets** (Settings → Secrets and variables → Actions):

| Secret                  | Origem                              |
| ----------------------- | ----------------------------------- |
| `AWS_ACCESS_KEY_ID`     | access key do usuário IAM da conta  |
| `AWS_SECRET_ACCESS_KEY` | secret dessa mesma access key       |
| `DOCKERHUB_USERNAME`    | usuário do Docker Hub               |
| `DOCKERHUB_TOKEN`       | Docker Hub → Personal access tokens |

**Variables** (mesma tela, aba Variables):

| Variable          | Valor                |
| ----------------- | -------------------- |
| `AWS_REGION`      | `us-east-1`          |
| `ECR_REPOSITORY`  | `cp04-devops`        |
| `EC2_INSTANCE_ID` | output `instance_id` |

O pipeline usa a mesma access key do usuário IAM da conta, a mesma que o
Terraform consome localmente.

## Fluxo de deploy

1. Commit em `main` alterando `app/**` dispara o workflow **CD**.
2. Um único `docker build` gera quatro tags: `cp04` e o SHA do commit, no ECR e
   no Docker Hub.
3. O deploy usa **SSM Send-Command** para executar `/usr/local/bin/deploy.sh` na
   instância, que faz login no ECR via IAM role, dá `docker pull` e recria o
   container. Nenhuma chave SSH trafega pelo pipeline.
4. O último passo confere via `curl` que o IP público responde, e escreve a URL
   no summary da execução.

## Rodar localmente

```bash
docker build -t portal:teste ./app
docker run -d --name portal-teste -p 80:80 portal:teste
# abrir http://localhost
docker rm -f portal-teste
```

## Destruir

```bash
cd infra
TF_DISABLE_PLUGIN_TLS=1 /c/Users/kaiki/bin/terraform.exe destroy
```

A instância e o ECR geram custo enquanto existirem.

---

# Roteiro de prints

Ordem sugerida dos prints. Cada bloco corresponde a um critério da avaliação.

## 1. Site personalizado — 1,5 ponto

| #   | Print                                               | Como obter                                                       |
| --- | --------------------------------------------------- | ---------------------------------------------------------------- |
| 1.1 | Página no navegador com os integrantes, RMs e turma | `docker run -d -p 80:80 portal:teste` e abrir `http://localhost` |

!["site_localhost"](./imgs/image.png)

| 1.2 | Trecho da página com o resumo de cgroups e namespaces | Rolar até as duas tabelas |
!["site_pq_container"](./imgs/image-2.png)
!["site_namespace"](./imgs/image-3.png)
!["como_entregue"](./imgs/image-4.png)
Os RMs precisam estar legíveis no print.

## 2. Dockerfile e build — 2,5 pontos

!["docker_running"](./imgs/image-1.png)
!["docker_terminal"](./imgs/image-5.png)


## 3. Imagem pública no Docker Hub com tag cp04 — 2,0 pontos
!["docker-hub"](./imgs/image-6.png)
!["docker-hub"](./imgs/image-7.png)

## 4. Container rodando na nuvem — 3,0 pontos

| #   | Print                                       | Como obter                                   |
| --- | ------------------------------------------- | -------------------------------------------- |
| 4.1 | `terraform apply` concluído com os outputs  | Capturar o bloco `Outputs:`                  |
| 4.2 | Instância EC2 no console, estado running    | Console AWS → EC2                            |
| 4.3 | Navegador com o portal aberto no IP público | `http://<ip_publico>`                        |
| 4.4 | `docker ps` dentro da EC2                   | `ssh -i infra/cp04-devops.pem ec2-user@<ip>` |

O print 4.3 é o que mais vale. A barra de endereço com o IP público precisa
estar visível — sem ela, parece localhost.

## 5. Extras

| #   | Print                                           | Como obter                    |
| --- | ----------------------------------------------- | ----------------------------- |
| 5.1 | VPC, sub-rede, IGW e tabela de rotas no console | —                             |
| 5.2 | Security group com as regras 80 e 22            | Console AWS → Security Groups |
| 5.3 | Workflow CI verde                               | Aba Actions                   |
| 5.4 | Workflow CD verde, com a URL no summary         | Aba Actions → CD → Summary    |
| 5.5 | Repositório ECR com a imagem `cp04`             | Console AWS → ECR             |

## Estrutura do PDF

1. Capa: integrantes, RMs, turma, disciplina, professor
2. Sumário dos entregáveis
3. Uma seção por bloco, com um parágrafo curto explicando o que o print prova
4. Encerramento: link do Docker Hub, link do repositório e o IP público usado

Legenda abaixo de cada print dizendo o que ele comprova.

## Observação a incluir no PDF

A EC2 puxa a imagem do ECR, não do Docker Hub. É o mesmo build, publicado nos
dois registries simultaneamente pelo pipeline — vale uma frase explicando isso,
senão parece que a imagem do Docker Hub não é a que está rodando.
