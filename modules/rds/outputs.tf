output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.main.endpoint
}

output "rds_port" {
  description = "RDS instance port"
  value       = aws_db_instance.main.port
}

output "rds_db_name" {
  description = "Database name"
  value       = aws_db_instance.main.db_name
}

output "master_user_secret_arn" {
  description = "Secrets Manager ARN for RDS master user credentials (IRSA에서 참조)"
  value       = aws_db_instance.main.master_user_secret[0].secret_arn
}
