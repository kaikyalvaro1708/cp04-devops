# Portal Arcanjo SA — Containerização do portal corporativo

FIAP · DevOps Tools & Cloud Computing

## Integrantes

- **Kaiky Alvaro de Miranda** — RM 98118
- **Juan Pinheiro de França** — RM 552202
- **Matheus Gusmão Aragão** — RM 550826
- **Júlia Marques Mendes das Neves** — RM 98680

Turma **4ESPW** · Professor Gabriel Henrique Boyczuk Arcanjo

**Portal no ar:** http://3.231.157.234
**Imagem pública:** `kaikyalvaro/cp04-devops:cp04`

## Sumário

1. [Contexto](#1-contexto)
2. [Arquitetura](#2-arquitetura)
3. [O site e o resumo para o Conselho](#3-o-site-e-o-resumo-para-o-conselho)
4. [Dockerfile e construção da imagem](#4-dockerfile-e-construção-da-imagem)
5. [Publicação no Docker Hub](#5-publicação-no-docker-hub)
6. [Infraestrutura como código](#6-infraestrutura-como-código)
7. [Pipeline de CI/CD](#7-pipeline-de-cicd)
8. [Container em execução na nuvem](#8-container-em-execução-na-nuvem)
9. [Reproduzir](#9-reproduzir)
10. [Conclusão](#10-conclusão)

---

## 1. Contexto

A Arcanjo SA migrou para a nuvem, mas cada desenvolvedor subia a aplicação de um
jeito diferente e o deploy dependia de como a máquina de destino estava
configurada. O CTO definiu que toda aplicação nova roda em container.

Este repositório é o piloto: o portal institucional foi empacotado em uma imagem
Docker, publicado em registry público e colocado em execução em uma instância
EC2. O mesmo artefato que roda na máquina do desenvolvedor roda na nuvem, sem
ajuste manual.

A entrega vai além do mínimo: toda a infraestrutura é descrita em Terraform, e o
ciclo completo — provisionar, construir, publicar e implantar — roda em um
pipeline de CI/CD. Nenhum comando é executado manualmente contra a AWS.

## 2. Arquitetura

```
app/                   index.html + Dockerfile
infra/                 Terraform: VPC, subnet, IGW, rotas, SG, ECR, IAM, EC2
.github/workflows/     ci.yml (lint, build, validate) e cd.yml (provisiona e implanta)
```

- **Aplicação**: `index.html` estático servido por `nginx:alpine` na porta 80
- **Rede**: VPC `10.0.0.0/24`, sub-rede pública com IPv4 automático, internet
  gateway e tabela de rotas com saída `0.0.0.0/0` associada à sub-rede
- **Segurança**: security group libera apenas a porta 80. Não há porta 22 aberta
  — o acesso administrativo é feito por SSM Session Manager
- **Registries**: Docker Hub (público) e Amazon ECR, consumido pela instância via
  IAM role, sem credencial gravada em disco
- **Computação**: EC2 `t3.micro` com Amazon Linux 2023, que instala o Docker e
  sobe o container no primeiro boot
- **Estado**: bucket S3 versionado e criptografado, guardando o estado do
  Terraform

---

## 3. O site e o resumo para o Conselho

O portal identifica os integrantes, RMs e turma, e explica em linguagem
executiva os dois mecanismos do kernel Linux que tornam containers viáveis.

!["Portal com integrantes, RMs e turma"](./imgs/image.png)

**Namespaces — o que o processo enxerga.** Definem o campo de visão de cada
container. Cada um recebe sua própria lista de processos, sua rede e seu sistema
de arquivos. Um container não vê os vizinhos, portanto não consegue interferir
neles. Os principais são PID (árvore de processos), NET (interfaces e portas),
MNT (pontos de montagem), UTS (hostname), IPC (comunicação entre processos) e
USER (mapeamento de usuários).

**Cgroups — o quanto ele pode consumir.** Definem a cota de recursos. O kernel
limita e contabiliza CPU, memória, disco e rede por grupo de processos. Um
container com defeito consome até o teto e para ali, sem derrubar o servidor.

**Em uma frase para o Conselho:** namespaces são as paredes do escritório, que
impedem cada equipe de ver e mexer na mesa da outra; cgroups são o orçamento
mensal, que impede uma equipe de gastar o dinheiro de todas. São controles
complementares — isolamento sem limite de consumo não evita que um vizinho
barulhento derrube a máquina, e limite sem isolamento não protege os dados.

!["Seção sobre containers no portal"](./imgs/image-2.png)
!["Tabela de namespaces"](./imgs/image-3.png)
<img src="./imgs/image-4.png" alt="Tabela de cgroups" width="100%">

---

## 4. Dockerfile e construção da imagem

A imagem parte de `nginx:1.27-alpine`, com a versão fixada para que o build de
hoje e o de daqui a três meses produzam o mesmo resultado. A variante Alpine
reduz a imagem a cerca de 20 MB comprimidos, diminuindo o tempo de pull e a
superfície de ataque. Um `HEALTHCHECK` faz o Docker reportar o container como
`healthy` apenas quando o servidor responde de fato, e não somente quando o
processo existe.

<img src="./imgs/image-1.png" alt="Container em execução com status healthy" width="100%">
<img src="./imgs/image-5.png" alt="Build da imagem concluído" width="100%">

---

## 5. Publicação no Docker Hub

A imagem está em repositório **público**, com a tag `cp04`. Qualquer pessoa pode
executá-la sem autenticação:

```bash
docker run -d -p 80:80 kaikyalvaro/cp04-devops:cp04
```

<img src="./imgs/image-6.png" alt="Repositório público no Docker Hub" width="100%">
<img src="./imgs/image-7.png" alt="Tag cp04 publicada" width="100%">

Além da `cp04`, o pipeline publica uma tag com o SHA de cada commit, o que
permite identificar qual versão do código gerou cada imagem e voltar a uma
anterior se necessário.

---

## 6. Infraestrutura como código

Os cinco passos de rede — VPC, sub-rede, internet gateway, tabela de rotas e
associação — que normalmente seriam feitos clicando no console estão versionados
em código, o que torna o ambiente reproduzível e auditável.

<img src="./imgs/image-11.png" alt="VPC, sub-rede, IGW e tabela de rotas" width="100%">
<img src="./imgs/image-17.png" alt="Security group com a regra da porta 80" width="100%">
<img src="./imgs/image-18.png" alt="Repositório ECR com a imagem publicada" width="100%">

Um detalhe relevante: é a **associação** entre a tabela de rotas e a sub-rede que
faz a rota valer. Sem ela a rota existe mas não se aplica, e a instância fica sem
acesso à internet — causa comum de falha ao tentar conectar em uma EC2.

---

## 7. Pipeline de CI/CD

**CI**, a cada pull request: lint do Dockerfile com `hadolint`, build da imagem,
subida do container e teste de fumaça confirmando resposta HTTP, mais
`terraform fmt -check` e `terraform validate`.

**CD**, a cada push na `main`:

1. Garante o bucket S3 de estado, de forma idempotente
2. Executa `terraform apply`, criando ou atualizando a infraestrutura
3. Lê os outputs do Terraform — o id da instância e o endereço do ECR não são
   cadastrados à mão em lugar nenhum
4. Um único `docker build` gera quatro tags: `cp04` e o SHA, no ECR e no Docker Hub
5. Aguarda o agente SSM registrar a instância e executa o deploy via Send-Command
6. Confirma com `curl` que o IP público responde antes de declarar sucesso

<img src="./imgs/image-8.png" alt="Workflow de CI concluído" width="100%">
<img src="./imgs/image-9.png" alt="Workflow de CD concluído" width="100%">
<img src="./imgs/image-12.png" alt="Steps da execução do CD" width="100%">

O deploy usa Systems Manager em vez de SSH: nenhuma chave privada trafega pelo
pipeline nem fica armazenada como segredo. O último passo é uma verificação real
de disponibilidade — se o portal não responder, o pipeline falha, evitando um
deploy silenciosamente quebrado.

---

## 8. Container em execução na nuvem

O portal está no ar em **http://3.231.157.234**, servido pelo container na
instância `i-0959fb2f3d8b50298` (`cp04-devops-ec2`), t3.micro, us-east-1.

<img src="./imgs/image-13.png" alt="Instância EC2 em estado running" width="100%">
<img src="./imgs/image-10.png" alt="Detalhes da instância" width="100%">
<img src="./imgs/image-14.png" alt="Portal aberto no IP público" width="100%">

Acesso à instância por Session Manager, sem chave SSH:

<img src="./imgs/image-15.png" alt="Conexão via Session Manager" width="100%">
<img src="./imgs/image-16.png" alt="docker ps dentro da EC2" width="100%">

A instância puxa a imagem do ECR, não do Docker Hub. É o mesmo build: o pipeline
publica nos dois registries na mesma execução, a partir de um único
`docker build`.

---

## 9. Reproduzir

Rodar localmente:

```bash
docker build -t portal:teste ./app
docker run -d --name portal-teste -p 80:80 portal:teste   # http://localhost
docker rm -f portal-teste
```

Validar a infraestrutura sem aplicar:

```bash
cd infra
terraform fmt -check -recursive && terraform init -backend=false && terraform validate
```

Segredos do pipeline (Settings → Secrets and variables → Actions):
`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`,
`DOCKERHUB_USERNAME` e `DOCKERHUB_TOKEN`.

Destruir — o estado vive no S3, então o destroy precisa do mesmo backend:

```bash
cd infra
CONTA=$(aws sts get-caller-identity --query Account --output text)
terraform init -input=false \
  -backend-config="bucket=cp04-devops-tfstate-$CONTA" \
  -backend-config="key=cp04-devops/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="use_lockfile=true"
terraform destroy
```

---

## 10. Conclusão

O piloto cumpriu o objetivo: o portal roda em container e o mesmo artefato
funciona em qualquer ambiente. A padronização eliminou a dependência de
configuração manual de máquina, e o pipeline removeu o deploy manual que era a
origem da inconsistência entre ambientes.

Do ponto de vista do negócio, o resultado é previsibilidade: qualquer pessoa da
equipe reproduz o ambiente inteiro a partir do repositório, e cada versão
publicada é rastreável até o commit que a originou.
