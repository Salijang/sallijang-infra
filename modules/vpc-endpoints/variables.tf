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
  description = "VPC ID"
}

variable "eks_subnet_ids" {
  type        = list(string)
  description = "EKS worker node subnet IDs — Interface 엔드포인트를 배치할 서브넷"
}

variable "private_route_table_ids" {
  type        = list(string)
  description = "Private route table IDs — S3 Gateway 엔드포인트에 연결"
}

variable "eks_sg_id" {
  type        = string
  description = "EKS 워커노드 보안 그룹 ID — Interface 엔드포인트 SG의 인바운드 소스"
}
