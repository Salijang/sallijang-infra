variable "project_name" {
  type        = string
  description = "프로젝트 이름"
}

variable "environment" {
  type        = string
  description = "배포 환경 (dev, prod)"
}

variable "visibility_timeout_seconds" {
  type        = number
  description = "메시지 처리 제한 시간 (초) — 파드가 이 시간 안에 처리해야 함"
  default     = 30
}

variable "message_retention_seconds" {
  type        = number
  description = "메인 큐 메시지 보관 기간 (초)"
  default     = 86400 # 1일
}

variable "max_receive_count" {
  type        = number
  description = "DLQ 이동 전 최대 수신 횟수"
  default     = 3
}

variable "allowed_sns_topic_arns" {
  type        = list(string)
  description = "SendMessage 권한을 부여할 SNS 토픽 ARN 목록"
  default     = []
}
