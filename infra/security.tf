resource "aws_security_group" "web" {
  name        = "${local.nome}-sg"
  description = "Libera HTTP para o mundo"
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

resource "aws_vpc_security_group_egress_rule" "saida" {
  security_group_id = aws_security_group.web.id
  description       = "Saida liberada para pull no ECR e agente SSM"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
