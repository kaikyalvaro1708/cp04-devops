terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.60" }
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

locals {
  nome = var.projeto
}
