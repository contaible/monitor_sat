# Outputs

output "instance_id" {
  description = "ID de la instancia EC2"
  value       = aws_instance.monitor_sat.id
}

output "public_ip" {
  description = "IP pública de la instancia"
  value       = aws_eip.monitor_sat.public_ip
}

output "domain_name" {
  description = "Nombre del dominio"
  value       = var.domain_name
}

output "ssh_command" {
  description = "Comando SSH para conectarse a la instancia"
  value       = "ssh -i ~/.ssh/${var.project_name}-key ubuntu@${aws_eip.monitor_sat.public_ip}"
}

output "application_url" {
  description = "URL de la aplicación"
  value       = "https://${var.domain_name}"
}

output "health_check_url" {
  description = "URL del health check"
  value       = "https://${var.domain_name}/"
}

output "secret_manager_arn" {
  description = "ARN del secret en AWS Secrets Manager"
  value       = aws_secretsmanager_secret.monitor_sat_credentials.arn
  sensitive   = true
}

output "vpc_id" {
  description = "ID de la VPC creada"
  value       = aws_vpc.main.id
}

output "security_group_id" {
  description = "ID del Security Group"
  value       = aws_security_group.monitor_sat.id
}

output "cloudwatch_log_group" {
  description = "Nombre del log group en CloudWatch"
  value       = aws_cloudwatch_log_group.monitor_sat.name
}

output "route53_nameservers" {
  description = "Name servers de Route53 (si se creó la zona)"
  value       = var.create_route53_zone ? aws_route53_zone.main[0].name_servers : []
}