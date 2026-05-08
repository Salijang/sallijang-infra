output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.main.endpoint
}

output "instance_id" {
  description = "RDS instance identifier (DBInstanceIdentifier) — CloudWatch 알람 dimension에 사용"
  value       = aws_db_instance.main.identifier
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

output "proxy_endpoint" {
  description = "RDS Proxy endpoint (파드에서 DB 접속 시 이 엔드포인트 사용)"
  value       = aws_db_proxy.main.endpoint
}

output "proxy_arn" {
  description = "RDS Proxy ARN"
  value       = aws_db_proxy.main.arn
}

output "read_replica_endpoint" {
  description = "Read Replica 엔드포인트 (enable_read_replica = true 시에만 값 있음)"
  value       = var.enable_read_replica ? aws_db_instance.read_replica[0].endpoint : null
}

output "read_replica_instance_id" {
  description = "Read Replica DBInstanceIdentifier (enable_read_replica = true 시에만 값 있음)"
  value       = var.enable_read_replica ? aws_db_instance.read_replica[0].identifier : null
}
