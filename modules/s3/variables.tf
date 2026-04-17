variable "project_name" {
  type        = string
  description = "프로젝트 이름"
}

variable "environment" {
  type        = string
  description = "배포 환경 (dev, prod)"
}

variable "glacier_transition_days" {
  type        = number
  description = "Glacier 전환까지의 일수"
  default     = 90
}

variable "log_expiration_days" {
  type        = number
  description = "로그 버킷 오브젝트 만료 일수 (0 = 만료 없음)"
  default     = 365
}

variable "force_destroy" {
  type        = bool
  description = "버킷 내 오브젝트가 있어도 강제 삭제 허용 (dev: true, prod: false)"
  default     = false
}
