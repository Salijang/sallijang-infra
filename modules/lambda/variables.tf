variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type        = string
  description = "Lambda VPC 배치용 VPC ID"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Lambda 배치 서브넷 (data subnet — NAT GW 아웃바운드 가능)"
}

variable "image_bucket_name" {
  type        = string
  description = "이미지 S3 버킷 이름 (이미지 리사이징 트리거 대상)"
}

variable "image_bucket_arn" {
  type        = string
  description = "이미지 S3 버킷 ARN"
}

variable "sns_topic_arn" {
  type        = string
  description = "알림 SNS 토픽 ARN (notify Lambda 트리거)"
}

# ── Lambda 코드 위치 (S3) ─────────────────────────────────────────────
# 비어 있으면 Lambda 함수를 생성하지 않습니다.
# CI/CD에서 코드를 S3에 업로드한 후 해당 버킷/키를 tfvars에 입력하세요.

variable "deploy_lambda" {
  type        = bool
  description = "Lambda 함수 생성 여부. false면 Lambda 관련 리소스 미생성."
  default     = false
}

variable "code_s3_bucket" {
  type        = string
  description = "Lambda 코드가 담긴 S3 버킷 이름."
  default     = ""
}

variable "image_resize_code_s3_key" {
  type        = string
  description = "이미지 리사이징 Lambda 코드 S3 키 (e.g. lambda/image-resize.zip)"
  default     = "lambda/image-resize.zip"
}

variable "sns_notify_code_s3_key" {
  type        = string
  description = "SNS 알림 Lambda 코드 S3 키 (e.g. lambda/sns-notify.zip)"
  default     = "lambda/sns-notify.zip"
}

variable "runtime" {
  type        = string
  description = "Lambda 런타임"
  default     = "nodejs20.x"
}

variable "timeout" {
  type        = number
  description = "Lambda 실행 제한 시간 (초)"
  default     = 30
}

variable "memory_size" {
  type        = number
  description = "Lambda 메모리 크기 (MB)"
  default     = 256
}

variable "image_resize_handler" {
  type    = string
  default = "index.handler"
}

variable "sns_notify_handler" {
  type    = string
  default = "handler.handler"
}

variable "sns_notify_runtime" {
  type        = string
  description = "SNS notify Lambda 런타임 (Python 코드)"
  default     = "python3.11"
}

variable "sqs_dlq_arn" {
  type        = string
  description = "DLQ ARN — sns-notify Lambda의 이벤트 소스로 등록하여 보상 이벤트를 발행합니다. 비우면 DLQ 트리거 미생성."
  default     = ""
}
