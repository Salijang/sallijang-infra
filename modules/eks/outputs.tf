# ── 클러스터 ──────────────────────────────────────────────────────────
output "cluster_name" {
  description = "EKS 클러스터 이름"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "EKS API 서버 엔드포인트"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_certificate_authority_data" {
  description = "EKS 클러스터 CA 인증서 (base64) — kubeconfig에 사용"
  value       = aws_eks_cluster.main.certificate_authority[0].data
}

output "cluster_version" {
  description = "EKS 클러스터 버전"
  value       = aws_eks_cluster.main.version
}

# ── OIDC (IRSA) ───────────────────────────────────────────────────────
output "oidc_provider_arn" {
  description = "OIDC Provider ARN — IRSA 모듈에서 IAM Role 생성 시 참조"
  value       = aws_iam_openid_connect_provider.main.arn
}

output "oidc_issuer_url" {
  description = "OIDC 발급자 URL (https:// 포함)"
  value       = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

# ── 노드 ──────────────────────────────────────────────────────────────
output "node_role_arn" {
  description = "워커 노드 IAM Role ARN — IRSA 정책에서 참조"
  value       = aws_iam_role.node.arn
}

output "node_sg_id" {
  description = "워커 노드 보안 그룹 ID"
  value       = aws_security_group.node.id
}

output "control_plane_sg_id" {
  description = "컨트롤 플레인 추가 보안 그룹 ID"
  value       = aws_security_group.control_plane.id
}
