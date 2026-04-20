variable "project_name" {
  type        = string
  description = "Project name"
}

variable "environment" {
  type        = string
  description = "Deployment environment (dev, prod)"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID (proxy SG 생성용)"
}

variable "data_subnet_ids" {
  type        = list(string)
  description = "Data subnet IDs for DB subnet group"
}

variable "eks_subnet_ids" {
  type        = list(string)
  description = "EKS subnet IDs where RDS Proxy is placed (pods connect here)"
}

variable "rds_sg_id" {
  type        = string
  description = "Security group ID for RDS"
}

variable "eks_sg_id" {
  type        = string
  description = "EKS worker node security group ID (proxy inbound source)"
}

variable "instance_class" {
  type        = string
  description = "RDS instance class"
  default     = "db.t3.small"
}

variable "allocated_storage" {
  type        = number
  description = "Allocated storage size in GB"
  default     = 20
}

variable "db_name" {
  type        = string
  description = "Database name"
}

variable "db_username" {
  type        = string
  description = "Database master username"
}

