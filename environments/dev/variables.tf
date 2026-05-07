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
  description = "EKS 최적화 AMI ID (Amazon Linux 2, ap-northeast-2). 조회: aws ec2 describe-images --owners amazon --filters 'Name=name,Values=amazon-eks-node-1.30-v*' --query 'sort_by(Images,&CreationDate)[-1].ImageId' --output text"
}

variable "eks_public_access_cidrs" {
  type        = list(string)
  description = "EKS API 서버 퍼블릭 접근 허용 CIDR. dev는 0.0.0.0/0 허용, prod는 사무실/VPN IP로 제한 필수."
}

variable "route53_zone_name" {
  type        = string
  description = "Route53 hosted zone의 apex 도메인 (e.g. sallijang.shop). ALB alias A 레코드 생성에 사용."
  default     = ""
}

variable "grafana_admin_password" {
  type        = string
  description = "Grafana 관리자 비밀번호. terraform.tfvars에 직접 쓰거나 TF_VAR_grafana_admin_password 환경 변수로 주입."
  sensitive   = true
}

variable "image_resize_code_s3_key" {
  type    = string
  default = "lambda/image-resize.zip"
}

variable "sns_notify_code_s3_key" {
  type    = string
  default = "lambda/sns-notify.zip"
}

variable "k6_runner_enabled" {
  type        = bool
  description = "k6 부하테스트용 EC2 runner 생성 여부."
  default     = true
}

variable "k6_runner_instance_type" {
  type        = string
  description = "k6 runner EC2 instance type."
  default     = "t3.medium"
}

variable "k6_runner_repo_url" {
  type        = string
  description = "k6 시나리오 레포 URL."
  default     = "https://github.com/Salijang/k6_test.git"
}

variable "k6_runner_repo_ref" {
  type        = string
  description = "k6 runner가 checkout할 git ref."
  default     = "main"
}

variable "k6_runner_base_url" {
  type        = string
  description = "k6 runner 기본 K6_BASE_URL."
  default     = "https://api.sallijang.shop"
}

variable "k6_runner_results_prefix" {
  type        = string
  description = "k6 결과를 업로드할 S3 prefix."
  default     = "k6-results/dev"
}
