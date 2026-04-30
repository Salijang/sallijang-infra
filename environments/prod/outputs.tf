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
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "eks_oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}

output "sns_topic_arn" {
  value = module.sns.topic_arn
}

output "sqs_queue_url" {
  value = module.sqs.queue_url
}

output "sqs_dlq_url" {
  value = module.sqs.dlq_url
}

output "s3_image_bucket" {
  value = module.s3.image_bucket_name
}

output "rds_master_user_secret_arn" {
  value = module.rds.master_user_secret_arn
}

output "rds_read_replica_endpoint" {
  description = "Read Replica 엔드포인트"
  value       = module.rds.read_replica_endpoint
}

output "lambda_image_resize_arn" {
  description = "이미지 리사이징 Lambda ARN (Lambda 미배포 시 null)"
  value       = module.lambda.image_resize_function_arn
}

output "lambda_sns_notify_arn" {
  description = "SNS 알림 Lambda ARN (Lambda 미배포 시 null)"
  value       = module.lambda.sns_notify_function_arn
}
