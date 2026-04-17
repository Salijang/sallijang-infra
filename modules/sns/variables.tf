variable "project_name" {
  type        = string
  description = "프로젝트 이름"
}

variable "environment" {
  type        = string
  description = "배포 환경 (dev, prod)"
}

variable "sqs_endpoint_arn" {
  type        = string
  description = "구독 대상 SQS 큐 ARN (비워두면 구독 생성 안 함)"
  default     = ""
}
