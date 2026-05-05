variable "project_name" {
  type        = string
  description = "프로젝트 이름"
}

variable "environment" {
  type        = string
  description = "배포 환경 (dev, prod)"
}

variable "lambda_function_names" {
  type        = list(string)
  description = "Log Group retention을 관리할 Lambda 함수명 리스트. 비어있으면 Log Group 리소스 미생성."
  default     = []
}

variable "log_retention_days" {
  type        = number
  description = "CloudWatch Log Group 보관 기간 (일). 비용 절감을 위해 환경별로 다르게 설정 (예: dev 30, prod 90)"
  default     = 30
}
