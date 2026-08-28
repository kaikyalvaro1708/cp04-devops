# CP04 — Portal Arcanjo SA containerizado

Checkpoint 04 de DevOps Tools & Cloud Computing — FIAP, turma 4ESPW.

O portal da Arcanjo SA empacotado em uma imagem Docker, publicado no Docker Hub
e no Amazon ECR, e executado em um container numa EC2 provisionada por Terraform.
Build, publicação e deploy rodam por pipeline, sem etapa manual.

## Estrutura

```
app/                     aplicação e Dockerfile juntos
  index.html             nome, RM, turma + resumo de cgroups e namespaces
  Dockerfile             nginx:alpine servindo o portal na porta 80
infra/                   Terraform: VPC, subnet, IGW, rotas, SG, ECR, IAM, EC2
  user_data.sh.tftpl     script que a EC2 executa no primeiro boot
.github/workflows/
  ci.yml                 em PR: lint do Dockerfile, build e smoke test
  cd.yml                 em main: push nos dois registries + deploy via SSM
```

## Como os entregáveis são atendidos

| Entregável do enunciado | Onde está |
|---|---|
| Site com nome, RM, turma e resumo de cgroups/namespaces | `app/index.html` |
| Dockerfile funcional | `app/Dockerfile` |
| Imagem no Docker Hub com a tag `cp04` | publicada pelo `cd.yml` |
| Container rodando em uma EC2 | `infra/ec2.tf` + `user_data.sh.tftpl` |
| PDF com os prints | roteiro na seção final deste README |

Os cinco passos do slide "AWS HELP" estão no `infra/network.tf`, cada um comentado
com o número do passo correspondente. O script de instalação do Docker do slide
seguinte está no `user_data.sh.tftpl`.

---

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

## Configurar a conta AWS do trabalho

Este projeto usa um profile dedicado (`fiap`), separado de qualquer conta de
trabalho. O provider aponta explicitamente para ele, então um `apply` acidental
falha em vez de criar recursos na conta errada.

1. Crie a conta AWS nova e entre no console.
2. IAM → Users → Create user → anexe a policy `AdministratorAccess`.
3. No usuário criado: Security credentials → Create access key → *Command Line
   Interface*.
4. Registre o profile localmente:

```bash
aws configure --profile fiap
# AWS Access Key ID:     <a chave do usuário novo>
# AWS Secret Access Key: <o segredo>
# Default region name:   us-east-1
# Default output format: json
```

5. Confirme que é a conta certa antes de qualquer `apply`:

```bash
aws sts get-caller-identity --profile fiap --no-verify-ssl
```

## Provisionar a infraestrutura

```bash
export TF_DISABLE_PLUGIN_TLS=1
cd infra
/c/Users/kaiki/bin/terraform.exe init
/c/Users/kaiki/bin/terraform.exe plan
/c/Users/kaiki/bin/terraform.exe apply
```

O `apply` cria 22 recursos e devolve os outputs usados nos passos seguintes:

| Output | Para que serve |
|--------|----------------|
| `url_do_portal` | Abrir no navegador e printar para o PDF |
| `ip_publico` | IP público da EC2 |
| `instance_id` | Vira a variável `EC2_INSTANCE_ID` no GitHub |
| `ecr_repository_url` | Vira a variável `ECR_REPOSITORY` no GitHub |
| `comando_ssh` | Conexão SSH com a chave gerada pelo Terraform |
| `github_secret_aws_access_key_id` | Secret `AWS_ACCESS_KEY_ID` (sensível) |
| `github_secret_aws_secret_access_key` | Secret `AWS_SECRET_ACCESS_KEY` (sensível) |

Para ler os sensíveis:

```bash
/c/Users/kaiki/bin/terraform.exe output -raw github_secret_aws_access_key_id
/c/Users/kaiki/bin/terraform.exe output -raw github_secret_aws_secret_access_key
```

A chave SSH é gerada pelo Terraform e salva em `infra/cp04-devops.pem`
(já ignorada pelo git — nunca commitar).

## Configurar o pipeline no GitHub

**Secrets** (Settings → Secrets and variables → Actions → Secrets):

| Secret | Origem |
|--------|--------|
| `AWS_ACCESS_KEY_ID` | output do Terraform |
| `AWS_SECRET_ACCESS_KEY` | output do Terraform |
| `DOCKERHUB_USERNAME` | seu usuário do Docker Hub |
| `DOCKERHUB_TOKEN` | Docker Hub → Account Settings → Personal access tokens |

**Variables** (mesma tela, aba Variables):

| Variable | Valor |
|----------|-------|
| `AWS_REGION` | `us-east-1` |
| `ECR_REPOSITORY` | `cp04-devops` |
| `EC2_INSTANCE_ID` | output `instance_id` |

## Fluxo de deploy

1. Commit em `main` alterando `app/**` dispara o workflow **CD**.
2. Um único `docker build` gera quatro tags: `cp04` e o SHA do commit, no ECR e
   no Docker Hub. A tag `cp04` no Docker Hub é o entregável avaliado.
3. O deploy usa **SSM Send-Command** para executar `/usr/local/bin/deploy.sh` na
   EC2, que faz login no ECR via IAM role, dá `docker pull` e recria o container.
   Nenhuma chave SSH trafega pelo pipeline.
4. O último passo confere via `curl` que o IP público responde, e escreve a URL
   no summary da execução.

## Rodar localmente

```bash
docker build -t portal:teste ./app
docker run -d --name portal-teste -p 80:80 portal:teste
# abrir http://localhost
docker rm -f portal-teste
```

---

# Roteiro de prints para o PDF

O critério "Documento organizado com todos os prints legíveis" vale 1,0 ponto.
Tire os prints **nesta ordem** — cada bloco corresponde a um critério da avaliação.

### 1. Site personalizado — 1,5 ponto

| # | Print | Como obter |
|---|-------|-----------|
| 1.1 | Página no navegador mostrando nome, RM e turma | `docker run -d -p 80:80 portal:teste` e abrir `http://localhost` |
| 1.2 | Trecho da página com o resumo de cgroups e namespaces | Rolar a mesma página até as duas tabelas |

> Garanta que o RM esteja **legível** no print. É o item que o professor procura primeiro.

### 2. Dockerfile e build — 2,5 pontos

| # | Print | Como obter |
|---|-------|-----------|
| 2.1 | Conteúdo do `app/Dockerfile` no editor | Abrir o arquivo no VS Code |
| 2.2 | Build concluído sem erro | `docker build -t portal:teste ./app` |
| 2.3 | Imagem listada localmente | `docker images` |
| 2.4 | Container local respondendo | `docker ps` + a aba do navegador em `localhost` |

### 3. Imagem pública no Docker Hub com tag cp04 — 2,0 pontos

| # | Print | Como obter |
|---|-------|-----------|
| 3.1 | Página do repositório no Docker Hub | `hub.docker.com/r/SEU_USUARIO/cp04-devops` |
| 3.2 | Aba **Tags** mostrando a tag `cp04` | Mesma página, aba Tags |
| 3.3 | Selo **Public** visível | Enquadrar o cabeçalho do repositório |

> A tag precisa ser exatamente `cp04` e o repositório precisa estar **público**.

### 4. Container rodando na nuvem — 3,0 pontos

| # | Print | Como obter |
|---|-------|-----------|
| 4.1 | `terraform apply` concluído com os outputs | Capturar o bloco `Outputs:` |
| 4.2 | Instância EC2 no console AWS, estado *running* | Console AWS → EC2 → Instâncias |
| 4.3 | Navegador com o portal aberto **na URL/IP público** | `http://<ip_publico>` |
| 4.4 | `docker ps` dentro da EC2 | `ssh -i infra/cp04-devops.pem ec2-user@<ip>` e depois `docker ps` |

> O print 4.3 é o que mais vale. A **barra de endereço com o IP público** precisa
> estar visível — sem ela parece localhost.

### 5. Extras que reforçam a entrega

| # | Print | Como obter |
|---|-------|-----------|
| 5.1 | VPC, sub-rede, IGW e tabela de rotas no console | Mostra os passos 1 a 5 do "AWS HELP" feitos via Terraform |
| 5.2 | Security group com as regras 80 e 22 | Console AWS → Security Groups → Regras de entrada |
| 5.3 | Workflow **CI** verde no GitHub Actions | Aba Actions → execução do CI |
| 5.4 | Workflow **CD** verde, com o resumo mostrando a URL | Aba Actions → execução do CD → Summary |
| 5.5 | Repositório ECR com a imagem `cp04` | Console AWS → ECR → Repositórios |

### Estrutura sugerida do PDF

1. Capa: nome, RM, turma, disciplina, professor
2. Sumário dos entregáveis
3. Uma seção por bloco acima, com um parágrafo curto explicando o que o print prova
4. Encerramento: link do Docker Hub, link do repositório GitHub e o IP público usado

> Escreva a legenda **abaixo** de cada print dizendo o que ele comprova. É isso que
> diferencia "documento organizado" de "pasta de imagens".

---

## Destruir tudo ao terminar

```bash
cd infra
TF_DISABLE_PLUGIN_TLS=1 /c/Users/kaiki/bin/terraform.exe destroy
```

Rode depois de tirar todos os prints. A EC2 e o ECR geram custo enquanto existirem.
