output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

output "eks_subnet_ids" {
  value = module.vpc.eks_subnet_ids
}

output "realtime_subnet_ids" {
  value = module.vpc.realtime_subnet_ids
}

output "data_subnet_ids" {
  value = module.vpc.data_subnet_ids
}

output "eks_cluster_name" {
  description = "EKS 클러스터 이름 — kubeconfig 업데이트 시 사용"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS API 서버 엔드포인트"
  value       = module.eks.cluster_endpoint
}

output "eks_oidc_provider_arn" {
  description = "OIDC Provider ARN — IRSA 구성 시 참조"
  value       = module.eks.oidc_provider_arn
}

output "sns_topic_arn" {
  description = "알림 SNS 토픽 ARN"
  value       = module.sns.topic_arn
}

output "sqs_queue_url" {
  description = "예약 처리 SQS 큐 URL"
  value       = module.sqs.queue_url
}

output "sqs_dlq_url" {
  description = "DLQ URL"
  value       = module.sqs.dlq_url
}

output "s3_image_bucket" {
  description = "이미지 버킷 이름"
  value       = module.s3.image_bucket_name
}

output "rds_master_user_secret_arn" {
  description = "RDS 마스터 계정 Secrets Manager ARN — IRSA 정책에서 참조"
  value       = module.rds.master_user_secret_arn
}
