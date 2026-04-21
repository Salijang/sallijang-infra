variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type        = string
  description = "VPC ID for target group"
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Public subnet IDs where ALB is deployed"
}

variable "alb_sg_id" {
  type        = string
  description = "ALB security group ID from VPC module"
}

variable "domain_name" {
  type        = string
  description = "Domain name for ACM certificate (e.g. pickup.example.com)"
}

variable "hosted_zone_id" {
  type        = string
  description = "Route53 hosted zone ID for ACM DNS validation. Leave empty to skip DNS record creation."
  default     = ""
}

variable "certificate_arn" {
  type        = string
  description = "기존 ACM 인증서 ARN. 제공 시 신규 발급 스킵 (Route53 없는 환경에서 사전 발급 후 입력)."
  default     = ""
}

variable "node_port" {
  type        = number
  description = "NodePort number on EKS worker nodes"
  default     = 30080
}

variable "route53_zone_name" {
  type        = string
  description = "Route53 hosted zone의 apex 도메인 (e.g. sallijang.shop). 입력 시 ALB alias A 레코드 자동 생성."
  default     = ""
}
