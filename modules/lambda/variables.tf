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

variable "code_s3_bucket" {
  type        = string
  description = "Lambda 코드 zip을 업로드할 S3 버킷 이름"
}

variable "deploy_lambda" {
  type        = bool
  description = "Lambda 함수 생성 여부. false면 Lambda 관련 리소스 미생성."
  default     = false
}

variable "image_resize_code_s3_key" {
  type        = string
  description = "이미지 리사이징 Lambda 코드 S3 키"
  default     = "lambda/image-resize.zip"
}

variable "sns_notify_code_s3_key" {
  type        = string
  description = "SNS 알림 Lambda 코드 S3 키"
  default     = "lambda/sns-notify.zip"
}

variable "image_resize_source_dir" {
  type        = string
  description = "image-resize Lambda 소스 디렉터리 절대경로 (handler.js + package.json 위치)"
  default     = ""
}

variable "sns_notify_source_dir" {
  type        = string
  description = "sns-notify Lambda 소스 디렉터리 절대경로 (handler.py 위치)"
  default     = ""
}

variable "runtime" {
  type        = string
  description = "image-resize Lambda 런타임"
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
  default = "handler.handler"
}

variable "sns_notify_handler" {
  type    = string
  default = "handler.handler"
}

variable "sns_notify_runtime" {
  type        = string
  description = "sns-notify Lambda 런타임"
  default     = "python3.11"
}

variable "sqs_dlq_arn" {
  type        = string
  description = "DLQ ARN — sns-notify Lambda 이벤트 소스. 비우면 DLQ 트리거 미생성."
  default     = ""
}
