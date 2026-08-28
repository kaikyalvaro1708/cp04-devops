variable "aws_region" {
  description = "Regiao AWS onde a infra sera criada."
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "Profile do ~/.aws/credentials usado para criar a infra. Mantenha separado da conta de trabalho."
  type        = string
  default     = "fiap"
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
  description = "CIDR da VPC (o PDF sugere 10.0.0.0/24)."
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
  description = "Tag da imagem consumida pela EC2. O entregavel exige cp04."
  type        = string
  default     = "cp04"
}

variable "ssh_cidr" {
  description = "CIDR liberado na porta 22. Deixe null para detectar seu IP publico automaticamente."
  type        = string
  default     = null
}

variable "github_repo" {
  description = "Repositorio no formato owner/nome, usado no nome do usuario IAM do pipeline."
  type        = string
  default     = "owner/cp04-devops"
}
