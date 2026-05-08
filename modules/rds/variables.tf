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

variable "max_allocated_storage" {
  type        = number
  description = "스토리지 자동 확장 상한 GB. 0이면 autoscaling 비활성화. prod는 반드시 설정."
  default     = 0
}

variable "backup_retention_period" {
  type        = number
  description = "자동 백업 보존 기간(일). Read Replica를 생성하려면 1 이상이어야 함."
  default     = 0

  validation {
    condition     = var.backup_retention_period >= 0 && var.backup_retention_period <= 35
    error_message = "backup_retention_period는 0에서 35 사이여야 합니다."
  }
}

variable "db_name" {
  type        = string
  description = "Database name"
}

variable "db_username" {
  type        = string
  description = "Database master username"
}

variable "multi_az" {
  type        = bool
  description = "Multi-AZ 활성화 여부 (prod: true)"
  default     = false
}

variable "skip_final_snapshot" {
  type        = bool
  description = "삭제 시 최종 스냅샷 생략 여부 (dev: true, prod: false)"
  default     = true
}

variable "deletion_protection" {
  type        = bool
  description = "삭제 보호 활성화 여부 (prod: true)"
  default     = false
}

variable "enable_read_replica" {
  type        = bool
  description = "Read Replica 생성 여부 (prod: true)"
  default     = false
}

variable "enable_performance_insights" {
  type        = bool
  description = "RDS Performance Insights 활성화 여부"
  default     = false
}

variable "performance_insights_retention_period" {
  type        = number
  description = "Performance Insights 데이터 보존 기간(일). 기본 7일."
  default     = 7
}

variable "enhanced_monitoring_interval" {
  type        = number
  description = "RDS Enhanced Monitoring 수집 주기(초). 0이면 비활성화."
  default     = 0

  validation {
    condition     = contains([0, 1, 5, 10, 15, 30, 60], var.enhanced_monitoring_interval)
    error_message = "enhanced_monitoring_interval은 0, 1, 5, 10, 15, 30, 60 중 하나여야 합니다."
  }
}
