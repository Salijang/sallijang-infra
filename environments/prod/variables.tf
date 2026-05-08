variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "availability_zones" {
  type = list(string)
}

variable "public_subnet_cidrs" {
  type = list(string)
}

variable "eks_subnet_cidrs" {
  type = list(string)
}

variable "realtime_subnet_cidrs" {
  type = list(string)
}

variable "data_subnet_cidrs" {
  type = list(string)
}

variable "domain_name" {
  type        = string
  description = "Domain name for ACM certificate"
}

variable "hosted_zone_id" {
  type    = string
  default = ""
}

variable "node_port" {
  type    = number
  default = 30080
}

variable "certificate_arn" {
  type    = string
  default = ""
}

variable "kubernetes_namespace" {
  type    = string
  default = "default"
}

variable "eks_node_ami_id" {
  type        = string
  description = "EKS 최적화 AMI ID (Amazon Linux 2, ap-northeast-2)"
}

variable "eks_public_access_cidrs" {
  type        = list(string)
  description = "EKS API 서버 퍼블릭 접근 허용 CIDR. prod는 사무실/VPN IP로 제한 필수. 0.0.0.0/0 사용 금지."
}

variable "route53_zone_name" {
  type    = string
  default = ""
}

variable "grafana_admin_password" {
  type      = string
  sensitive = true
}

variable "alertmanager_slack_webhook_url" {
  type        = string
  description = "Alertmanager Slack incoming webhook URL. 비우면 PrometheusRule Slack 발송을 구성하지 않음."
  default     = ""
  sensitive   = true
}

variable "alertmanager_slack_channel" {
  type        = string
  description = "Alertmanager가 알림을 보낼 Slack 채널명."
  default     = "#alerts"
}

variable "slack_workspace_id" {
  type        = string
  description = "AWS Chatbot Slack workspace/team ID. 비우면 CloudWatch Alarm Slack 발송을 구성하지 않음."
  default     = ""
}

variable "slack_channel_id" {
  type        = string
  description = "AWS Chatbot Slack channel ID. 비우면 CloudWatch Alarm Slack 발송을 구성하지 않음."
  default     = ""
}

# ── Lambda 코드 위치 ──────────────────────────────────────────────────
variable "image_resize_code_s3_key" {
  type    = string
  default = "lambda/image-resize.zip"
}

variable "sns_notify_code_s3_key" {
  type    = string
  default = "lambda/sns-notify.zip"
}
