variable "enabled" {
  type        = bool
  description = "Whether to create the k6 runner EC2 resources."
  default     = true
}

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_id" {
  type        = string
  description = "Subnet where the k6 runner is launched. Use a public subnet unless SSM/GitHub/S3 VPC endpoints or NAT are configured."
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type for the k6 runner."
  default     = "t3.medium"
}

variable "ami_id" {
  type        = string
  description = "Optional AMI override. Defaults to the latest Amazon Linux 2023 x86_64 AMI."
  default     = null
}

variable "associate_public_ip_address" {
  type        = bool
  description = "Attach a public IP so the runner can reach GitHub, package repositories, AWS APIs, and the public API without NAT."
  default     = true
}

variable "root_volume_size" {
  type        = number
  description = "Root EBS volume size in GiB."
  default     = 20
}

variable "k6_repo_url" {
  type        = string
  description = "Git repository containing the k6 scenarios."
  default     = "https://github.com/Salijang/k6_test.git"
}

variable "k6_repo_ref" {
  type        = string
  description = "Git ref checked out by the runner bootstrap."
  default     = "main"
}

variable "k6_base_url" {
  type        = string
  description = "Default K6_BASE_URL used by runner executions. Override per run when needed."
  default     = ""
}

variable "results_bucket_name" {
  type        = string
  description = "S3 bucket name for optional k6 result uploads."
  default     = ""
}

variable "results_bucket_arn" {
  type        = string
  description = "S3 bucket ARN for optional k6 result uploads."
  default     = ""
}

variable "results_prefix" {
  type        = string
  description = "S3 prefix for k6 result uploads."
  default     = "k6-results"
}

variable "tags" {
  type        = map(string)
  description = "Additional tags applied to runner resources."
  default     = {}
}
