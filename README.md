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
security group libera apenas a porta 80 para a internet. Não há porta 22 aberta:
o acesso à instância, quando necessário, é feito por SSM Session Manager.

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

## Provisionamento

A infraestrutura **não é aplicada manualmente**. O `terraform apply` roda dentro
do workflow de CD, a cada push na `main`. Isso garante que o que está na AWS é
sempre o que está versionado, sem divergência entre a máquina de alguém e o
ambiente real.

O estado fica em um bucket S3 (`cp04-devops-tfstate-<conta>`), com versionamento
e bloqueio por lockfile. O runner é descartável, então o estado precisa viver
fora dele; o próprio workflow cria o bucket na primeira execução, de forma
idempotente.

Para validar as alterações localmente, sem tocar em nada:

```bash
cd infra
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
```

Outputs produzidos pelo apply e consumidos pelos passos seguintes do pipeline:

| Output               | Uso                                |
|----------------------|------------------------------------|
| `url_do_portal`      | URL pública do portal              |
| `ip_publico`         | Alvo do smoke test final           |
| `instance_id`        | Destino do comando de deploy       |
| `ecr_repository_url` | Endereço das tags publicadas       |

## Configurar o pipeline

Tudo em **Secrets** (Settings → Secrets and variables → Actions). Nada é
cadastrado como *variable*.

| Secret                  | Valor                               |
| ----------------------- | ----------------------------------- |
| `AWS_ACCESS_KEY_ID`     | access key do usuário IAM da conta  |
| `AWS_SECRET_ACCESS_KEY` | secret dessa mesma access key       |
| `AWS_REGION`            | `us-east-1`                         |
| `DOCKERHUB_USERNAME`    | usuário do Docker Hub               |
| `DOCKERHUB_TOKEN`       | Docker Hub → Personal access tokens |

O id da instância e o endereço do ECR não são cadastrados em lugar nenhum: saem
dos outputs do Terraform durante a própria execução do workflow.

## Fluxo de deploy

1. Push na `main` dispara o workflow **CD**.
2. O workflow garante o bucket de estado e roda `terraform apply`, criando ou
   atualizando a infraestrutura. Nas execuções seguintes o plano fica vazio e o
   passo é praticamente instantâneo.
3. Os outputs do Terraform alimentam os passos seguintes: id da instância e
   endereço do ECR não são cadastrados à mão em lugar nenhum.
4. Um único `docker build` gera quatro tags: `cp04` e o SHA do commit, no ECR e
   no Docker Hub.
5. O pipeline espera o agente SSM ficar online — numa instância recém-criada ele
   leva um tempo a se registrar — e então usa **SSM Send-Command** para executar
   `/usr/local/bin/deploy.sh`, que faz login no ECR via IAM role, dá `docker
   pull` e recria o container. Nenhuma chave SSH trafega pelo pipeline.
6. O último passo confere via `curl` que o IP público responde, e escreve a URL
   no summary da execução.

## Rodar localmente

```bash
docker build -t portal:teste ./app
docker run -d --name portal-teste -p 80:80 portal:teste
# abrir http://localhost
docker rm -f portal-teste
```

## Destruir

O estado vive no S3, então o `destroy` precisa apontar para o mesmo backend:

```bash
cd infra
CONTA=$(aws sts get-caller-identity --query Account --output text)
terraform init -input=false   -backend-config="bucket=cp04-devops-tfstate-$CONTA"   -backend-config="key=cp04-devops/terraform.tfstate"   -backend-config="region=us-east-1"   -backend-config="use_lockfile=true"
terraform destroy
```

A instância e o ECR geram custo enquanto existirem. O bucket de estado não é
removido pelo `destroy` — apague à parte, se quiser limpar tudo.

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
| 4.1 | Step do `terraform apply` no Actions        | Aba Actions → execução do CD                 |
| 4.2 | Instância EC2 no console, estado running    | Console AWS → EC2                            |
| 4.3 | Navegador com o portal aberto no IP público | `http://<ip_publico>`                        |
| 4.4 | `docker ps` dentro da EC2                   | Console AWS → EC2 → Connect → Session Manager |

O print 4.3 é o que mais vale. A barra de endereço com o IP público precisa
estar visível — sem ela, parece localhost.

## 5. Extras

| #   | Print                                           | Como obter                    |
| --- | ----------------------------------------------- | ----------------------------- |
| 5.1 | VPC, sub-rede, IGW e tabela de rotas no console | —                             |
| 5.2 | Security group com a regra da porta 80          | Console AWS → Security Groups |
| 5.3 | Workflow CI verde                               | Aba Actions                   |
!["pipeline-ci"](,/imgs/image-8.png)
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
