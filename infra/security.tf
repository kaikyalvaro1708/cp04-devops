resource "aws_security_group" "web" {
  name        = "${local.nome}-sg"
  description = "Libera HTTP para o mundo e SSH apenas para o IP do aluno"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "${local.nome}-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.web.id
  description       = "Portal da Arcanjo SA servido pelo container"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.web.id
  description       = "SSH restrito ao IP publico do aluno"
  cidr_ipv4         = local.ssh_cidr
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "saida" {
  security_group_id = aws_security_group.web.id
  description       = "Saida liberada para pull no ECR e agente SSM"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# Chave SSH gerada pelo Terraform e salva localmente
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "ssh" {
  key_name   = "${local.nome}-key"
  public_key = tls_private_key.ssh.public_key_openssh
}

resource "local_sensitive_file" "chave_privada" {
  content         = tls_private_key.ssh.private_key_pem
  filename        = "${path.module}/${local.nome}.pem"
  file_permission = "0400"
}
