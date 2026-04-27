output "vpc_endpoint_sg_id" {
  description = "Interface Endpoint 전용 보안 그룹 ID"
  value       = aws_security_group.vpc_endpoint.id
}

output "s3_endpoint_id" {
  description = "S3 Gateway Endpoint ID"
  value       = aws_vpc_endpoint.s3.id
}

output "interface_endpoint_ids" {
  description = "Interface Endpoint ID 맵 (key: 서비스명, value: endpoint ID)"
  value       = { for k, v in aws_vpc_endpoint.interface : k => v.id }
}
