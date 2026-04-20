variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

# EKS OIDC (EKS 모듈 output 참조)
variable "oidc_provider_arn" {
  type        = string
  description = "EKS OIDC Provider ARN (module.eks.oidc_provider_arn)"
}

variable "oidc_issuer_url" {
  type        = string
  description = "EKS OIDC Issuer URL with https:// (module.eks.oidc_issuer_url)"
}

# SQS (SQS 모듈 output 참조)
variable "sqs_queue_arn" {
  type        = string
  description = "예약 처리 SQS 큐 ARN (module.sqs.queue_arn)"
}

variable "sqs_dlq_arn" {
  type        = string
  description = "DLQ ARN (module.sqs.dlq_arn)"
}

# SNS (SNS 모듈 output 참조)
variable "sns_topic_arn" {
  type        = string
  description = "SNS 토픽 ARN (module.sns.topic_arn)"
}

# S3 (S3 모듈 output 참조)
variable "image_bucket_arn" {
  type        = string
  description = "이미지 버킷 ARN (module.s3.image_bucket_arn)"
}

# Kubernetes 네임스페이스
variable "kubernetes_namespace" {
  type        = string
  description = "ServiceAccount가 위치할 Kubernetes 네임스페이스"
  default     = "default"
}
