# VPC
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = aws_vpc.main.cidr_block
}

# Subnets
output "public_subnet_ids" {
  description = "Public subnet IDs (ALB, NAT GW)"
  value       = aws_subnet.public[*].id
}

output "eks_subnet_ids" {
  description = "EKS worker node subnet IDs"
  value       = aws_subnet.eks[*].id
}

output "realtime_subnet_ids" {
  description = "Realtime subnet IDs (Redis)"
  value       = aws_subnet.realtime[*].id
}

output "data_subnet_ids" {
  description = "Data subnet IDs (RDS)"
  value       = aws_subnet.data[*].id
}

# Security Groups
output "alb_sg_id" {
  description = "ALB Security Group ID"
  value       = aws_security_group.alb.id
}

output "eks_sg_id" {
  description = "EKS Security Group ID"
  value       = aws_security_group.eks.id
}

output "rds_sg_id" {
  description = "RDS Security Group ID"
  value       = aws_security_group.rds.id
}

output "redis_sg_id" {
  description = "Redis Security Group ID"
  value       = aws_security_group.redis.id
}

# Route Tables
output "private_route_table_ids" {
  description = "Private route table IDs (AZ별, S3 Gateway Endpoint 연결용)"
  value       = aws_route_table.private[*].id
}
