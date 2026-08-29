output "url_do_portal" {
  description = "URL publica do portal."
  value       = "http://${aws_instance.portal.public_ip}"
}

output "ip_publico" {
  description = "IP publico da EC2."
  value       = aws_instance.portal.public_ip
}

output "instance_id" {
  description = "Id da instancia, usado pelo workflow de deploy."
  value       = aws_instance.portal.id
}

output "ecr_repository_url" {
  description = "URL do repositorio ECR."
  value       = aws_ecr_repository.app.repository_url
}

output "comando_ssh" {
  description = "Conexao SSH usando a chave gerada pelo Terraform."
  value       = "ssh -i ${local.nome}.pem ec2-user@${aws_instance.portal.public_ip}"
}
