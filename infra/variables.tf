variable "aws_region" {
  description = "Regiao AWS onde a infra sera criada."
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "Profile local do AWS CLI. Nulo no pipeline, onde as credenciais vem do ambiente."
  type        = string
  default     = null
}

variable "projeto" {
  description = "Prefixo usado no nome de todos os recursos."
  type        = string
  default     = "cp04-devops"
}

variable "turma" {
  description = "Turma, usada apenas como tag."
  type        = string
  default     = "4ESPW"
}

variable "vpc_cidr" {
  description = "CIDR da VPC."
  type        = string
  default     = "10.0.0.0/24"
}

variable "subnet_cidr" {
  description = "CIDR da sub-rede publica, precisa estar dentro da VPC."
  type        = string
  default     = "10.0.0.0/28"
}

variable "instance_type" {
  description = "Tipo da instancia EC2."
  type        = string
  default     = "t3.micro"
}

variable "container_name" {
  description = "Nome do container que roda na EC2."
  type        = string
  default     = "portal-arcanjo"
}

variable "image_tag" {
  description = "Tag da imagem consumida pela EC2."
  type        = string
  default     = "cp04"
}

