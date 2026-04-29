variable "project_name" {
  type        = string
  description = "프로젝트 이름"
}

variable "environment" {
  type        = string
  description = "배포 환경 (dev, prod)"
}

variable "force_destroy" {
  type        = bool
  description = "버킷 내 오브젝트가 있어도 강제 삭제 허용 (dev: true, prod: false)"
  default     = false
}

# ── 로그 prefix별 Glacier 전환 / 만료 일수 ───────────────────────────

variable "alb_log_glacier_days" {
  type        = number
  description = "ALB 로그 Glacier IR 전환 일수"
  default     = 30
}

variable "alb_log_expire_days" {
  type        = number
  description = "ALB 로그 만료 일수"
  default     = 365
}

variable "cloudfront_log_glacier_days" {
  type        = number
  description = "CloudFront 로그 Glacier IR 전환 일수"
  default     = 30
}

variable "cloudfront_log_expire_days" {
  type        = number
  description = "CloudFront 로그 만료 일수"
  default     = 365
}

variable "application_log_glacier_days" {
  type        = number
  description = "애플리케이션 로그 Glacier IR 전환 일수 (디버깅 접근 고려)"
  default     = 60
}

variable "application_log_expire_days" {
  type        = number
  description = "애플리케이션 로그 만료 일수"
  default     = 730
}

variable "vpc_flow_log_glacier_days" {
  type        = number
  description = "VPC Flow 로그 Glacier IR 전환 일수"
  default     = 30
}

variable "vpc_flow_log_expire_days" {
  type        = number
  description = "VPC Flow 로그 만료 일수"
  default     = 365
}
