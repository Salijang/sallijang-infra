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
  description = "구독 대상 SQS 큐 ARN"
}

variable "create_sqs_subscription" {
  type        = bool
  description = "SNS → SQS 구독 생성 여부 (computed ARN을 count에 쓸 수 없어 별도 플래그 사용)"
  default     = true
}
