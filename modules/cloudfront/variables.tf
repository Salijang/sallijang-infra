variable "project_name" {
  type        = string
  description = "Project name"
}

variable "environment" {
  type        = string
  description = "Deployment environment (dev, prod)"
}

variable "image_bucket_name" {
  type        = string
  description = "이미지 S3 버킷 이름 — OAC 버킷 정책 적용 대상"
}

variable "image_bucket_arn" {
  type        = string
  description = "이미지 S3 버킷 ARN"
}

variable "image_bucket_regional_domain_name" {
  type        = string
  description = "이미지 S3 버킷 리전 도메인명 — CloudFront Origin"
}

variable "frontend_bucket_name" {
  type        = string
  description = "프론트엔드 S3 버킷 이름"
}

variable "frontend_bucket_arn" {
  type        = string
  description = "프론트엔드 S3 버킷 ARN"
}

variable "frontend_bucket_regional_domain_name" {
  type        = string
  description = "프론트엔드 S3 버킷 리전 도메인명 — CloudFront Origin"
}

variable "log_bucket_domain_name" {
  type        = string
  description = "로그 S3 버킷 도메인명 (.s3.amazonaws.com) — CloudFront logging_config"
}

variable "hosted_zone_id" {
  type        = string
  description = "Route53 hosted zone ID"
}

variable "domain_name" {
  type        = string
  description = "기본 도메인 (e.g. sallijang.shop)"
}

variable "route53_zone_name" {
  type        = string
  description = "Route53 hosted zone apex 도메인"
}
