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
  description = "이미지 S3 버킷 ARN — 버킷 정책 Resource 필드"
}

variable "image_bucket_regional_domain_name" {
  type        = string
  description = "이미지 S3 버킷 리전 도메인명 — CloudFront Origin 도메인"
}

variable "hosted_zone_id" {
  type        = string
  description = "Route53 hosted zone ID — ACM DNS 검증 레코드 및 CDN A 레코드 생성"
}

variable "domain_name" {
  type        = string
  description = "기본 도메인 (e.g. sallijang.shop) — cdn. 서브도메인 생성에 사용"
}

variable "route53_zone_name" {
  type        = string
  description = "Route53 hosted zone apex 도메인 (e.g. sallijang.shop)"
}
