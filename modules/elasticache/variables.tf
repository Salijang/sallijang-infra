variable "project_name" {
  description = "프로젝트 이름"
  type        = string
}

variable "environment" {
  description = "배포 환경 (dev, prod)"
  type        = string
}

variable "realtime_subnet_ids" {
  description = "ElastiCache 서브넷 ID 목록 (realtime tier)"
  type        = list(string)
}

variable "redis_sg_id" {
  description = "Redis 보안 그룹 ID (vpc 모듈 output)"
  type        = string
}

variable "node_type" {
  description = "ElastiCache 노드 타입 (dev: cache.t3.micro, prod: cache.t3.small)"
  type        = string
  default     = "cache.t3.micro"
}

variable "redis_version" {
  description = "Redis 엔진 버전"
  type        = string
  default     = "7.0"
}

variable "num_cache_clusters" {
  description = "클러스터 수 (primary 1 + replica 1 = 2, Multi-AZ)"
  type        = number
  default     = 2
}
