# PASSO 1 do AWS HELP: VPC e sub-rede
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${local.nome}-vpc" }
}

data "aws_availability_zones" "disponiveis" {
  state = "available"
}

# PASSO 5 do AWS HELP: IPv4 publico automatico na sub-rede
resource "aws_subnet" "publica" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet_cidr
  availability_zone       = data.aws_availability_zones.disponiveis.names[0]
  map_public_ip_on_launch = true

  tags = { Name = "${local.nome}-subnet-publica" }
}

# PASSO 2 do AWS HELP: internet gateway criado e conectado a VPC
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = { Name = "${local.nome}-igw" }
}

# PASSO 3 do AWS HELP: tabela de rotas com saida 0.0.0.0/0 pelo IGW
resource "aws_route_table" "publica" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = { Name = "${local.nome}-rtb-publica" }
}

# PASSO 4 do AWS HELP: sem esta associacao a rota existe mas nao vale para a sub-rede
resource "aws_route_table_association" "publica" {
  subnet_id      = aws_subnet.publica.id
  route_table_id = aws_route_table.publica.id
}
