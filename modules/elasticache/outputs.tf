output "primary_endpoint_address" {
  description = "Redis primary 엔드포인트 (쓰기)"
  value       = aws_elasticache_replication_group.main.primary_endpoint_address
}

output "reader_endpoint_address" {
  description = "Redis reader 엔드포인트 (읽기)"
  value       = aws_elasticache_replication_group.main.reader_endpoint_address
}

output "port" {
  description = "Redis 포트"
  value       = aws_elasticache_replication_group.main.port
}

output "replication_group_id" {
  description = "Replication Group ID"
  value       = aws_elasticache_replication_group.main.replication_group_id
}
