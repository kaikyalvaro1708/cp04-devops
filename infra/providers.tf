terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws   = { source = "hashicorp/aws", version = "~> 5.60" }
    tls   = { source = "hashicorp/tls", version = "~> 4.0" }
    local = { source = "hashicorp/local", version = "~> 2.5" }
    http  = { source = "hashicorp/http", version = "~> 3.4" }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = {
      Projeto    = var.projeto
      Disciplina = "DevOps Tools and Cloud Computing"
      Turma      = var.turma
      ManagedBy  = "Terraform"
    }
  }
}

data "http" "meu_ip" {
  count = var.ssh_cidr == null ? 1 : 0
  url   = "https://checkip.amazonaws.com"
}

locals {
  ssh_cidr = var.ssh_cidr != null ? var.ssh_cidr : "${chomp(data.http.meu_ip[0].response_body)}/32"
  nome     = var.projeto
}
