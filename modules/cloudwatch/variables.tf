variable "project_name" {
  type        = string
  description = "프로젝트 이름"
}

variable "environment" {
  type        = string
  description = "배포 환경 (dev, prod)"
}

variable "lambda_function_names" {
  type        = list(string)
  description = "Log Group retention을 관리할 Lambda 함수명 리스트. 비어있으면 Log Group 리소스 미생성."
  default     = []
}

variable "log_retention_days" {
  type        = number
  description = "CloudWatch Log Group 보관 기간 (일). 비용 절감을 위해 환경별로 다르게 설정 (예: dev 30, prod 90)"
  default     = 30
}

# ── Metric Alarms ─────────────────────────────────────────────────────
variable "enable_alarms" {
  type        = bool
  description = "Metric Alarm 생성 여부. 단계적 롤아웃을 위해 false로 시작 가능."
  default     = false
}

variable "sns_topic_arn" {
  type        = string
  description = "알람 트리거 시 통지할 SNS 토픽 ARN. enable_alarms = true일 때 필수."
  default     = ""
}

variable "rds_instance_id" {
  type        = string
  description = "RDS 인스턴스 식별자. 비어있으면 RDS 알람 미생성."
  default     = ""
}

variable "alb_arn_suffix" {
  type        = string
  description = "ALB ARN suffix. 비어있으면 ALB 알람 미생성."
  default     = ""
}

variable "cloudfront_distribution_ids" {
  type        = list(string)
  description = "감시 대상 CloudFront Distribution ID 리스트. 비어있으면 CloudFront 알람 미생성."
  default     = []
}

variable "lambda_timeout_seconds" {
  type        = number
  description = "Lambda Duration p95 알람 임계 계산용 타임아웃(초). Duration > 80% × timeout일 때 알람."
  default     = 30
}
