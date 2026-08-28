output "url_do_portal" {
  description = "Abra no navegador e tire o print para o PDF."
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

output "github_secret_aws_access_key_id" {
  description = "Valor do secret AWS_ACCESS_KEY_ID no GitHub."
  value       = aws_iam_access_key.ci.id
  sensitive   = true
}

output "github_secret_aws_secret_access_key" {
  description = "Valor do secret AWS_SECRET_ACCESS_KEY no GitHub."
  value       = aws_iam_access_key.ci.secret
  sensitive   = true
}
