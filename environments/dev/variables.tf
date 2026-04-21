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
  type        = string
  description = "Route53 hosted zone ID for ACM DNS validation (optional)"
  default     = ""
}

variable "node_port" {
  type        = number
  description = "NodePort number on EKS worker nodes"
  default     = 30080
}

variable "certificate_arn" {
  type        = string
  description = "기존 ACM 인증서 ARN. AWS 콘솔에서 수동 발급 후 입력. 비우면 신규 발급 시도."
  default     = ""
}

variable "kubernetes_namespace" {
  type        = string
  description = "Kubernetes namespace for ServiceAccounts"
  default     = "default"
}

variable "eks_node_ami_id" {
  type        = string
  description = "EKS 최적화 AMI ID (Amazon Linux 2, ap-northeast-2). 조회: aws ec2 describe-images --owners amazon --filters 'Name=name,Values=amazon-eks-node-1.29-v*' --query 'sort_by(Images,&CreationDate)[-1].ImageId' --output text"
}

variable "route53_zone_name" {
  type        = string
  description = "Route53 hosted zone의 apex 도메인 (e.g. sallijang.shop). ALB alias A 레코드 생성에 사용."
  default     = ""
}
