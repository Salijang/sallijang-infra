variable "project_name" {
  type        = string
  description = "프로젝트 이름"
}

variable "environment" {
  type        = string
  description = "배포 환경 (dev, prod)"
}

variable "cluster_name" {
  type        = string
  description = "EKS 클러스터 이름 — IRSA 조건 및 EKS Access Entry에 사용"
}

variable "oidc_provider_arn" {
  type        = string
  description = "EKS OIDC Provider ARN — IRSA Trust Policy에 사용"
}

variable "oidc_issuer_url" {
  type        = string
  description = "EKS OIDC 발급자 URL (https:// 포함) — IRSA 조건에 사용"
}

variable "eks_subnet_ids" {
  type        = list(string)
  description = "EKS 워커 노드 서브넷 ID 목록 — karpenter.sh/discovery 태그 부착 대상"
}

variable "node_sg_id" {
  type        = string
  description = "EKS 워커 노드 보안 그룹 ID — karpenter.sh/discovery 태그 부착 대상"
}
