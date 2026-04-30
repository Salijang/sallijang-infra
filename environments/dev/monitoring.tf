# monitoring.tf
# EBS CSI Driver + gp3 StorageClass + kube-prometheus-stack (Prometheus + Grafana)

locals {
  # "https://oidc.eks.ap-northeast-2.amazonaws.com/id/XXXX" → "oidc.eks.ap-northeast-2.amazonaws.com/id/XXXX"
  oidc_issuer_host = replace(module.eks.oidc_issuer_url, "https://", "")
}

# ── EBS CSI Driver: IRSA Role ──────────────────────────────────────────
# EKS 1.29에서 PersistentVolume(EBS)을 사용하려면 EBS CSI Driver가 필수입니다.
# IRSA: EBS CSI 컨트롤러 ServiceAccount에 IAM 권한을 부여합니다.
resource "aws_iam_role" "ebs_csi_driver" {
  name = "${var.project_name}-${var.environment}-ebs-csi-driver-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = module.eks.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_issuer_host}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
          "${local.oidc_issuer_host}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = { Name = "${var.project_name}-${var.environment}-ebs-csi-driver-role" }
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  role       = aws_iam_role.ebs_csi_driver.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# ── EKS Addon: EBS CSI Driver ─────────────────────────────────────────
# EKS 관리형 애드온으로 설치 — 버전 관리 및 업데이트를 AWS가 처리합니다.
resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name             = module.eks.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  service_account_role_arn = aws_iam_role.ebs_csi_driver.arn

  # 충돌 시 기존 설정 덮어쓰기 (최초 설치 및 재적용 안전하게)
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [
    module.eks,
    aws_iam_role_policy_attachment.ebs_csi_driver,
  ]

  tags = { Name = "${var.project_name}-${var.environment}-ebs-csi-driver" }
}

# ── StorageClass: gp3 ────────────────────────────────────────────────
# EBS CSI Driver 설치 후 gp3 타입 StorageClass를 생성합니다.
#
# WaitForFirstConsumer: Pod가 스케줄된 AZ에 EBS 볼륨을 생성합니다.
#   → AZ 미스매치 방지 (노드가 ap-northeast-2a에 있는데 EBS가 2c에 생기는 문제 예방)
# Retain: Pod/PVC 삭제 시 EBS 볼륨 데이터를 보존합니다.
resource "kubernetes_storage_class_v1" "gp3" {
  metadata {
    name = "gp3"
  }

  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Retain"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true

  parameters = {
    type      = "gp3"
    encrypted = "true"
  }

  depends_on = [aws_eks_addon.ebs_csi_driver]
}

# ── kube-prometheus-stack ─────────────────────────────────────────────
# 포함 컴포넌트:
#   - Prometheus       : 메트릭 수집·저장 (10Gi EBS gp3)
#   - Grafana          : 대시보드 시각화  ( 5Gi EBS gp3)
#   - AlertManager     : 알림 발송 (emptyDir, dev 환경)
#   - Node Exporter    : EC2 노드 CPU/메모리/디스크 메트릭 (DaemonSet)
#   - kube-state-metrics: Pod/Deployment/ReplicaSet 상태 메트릭
resource "helm_release" "kube_prometheus_stack" {
  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = "65.1.1"
  namespace        = "default"
  create_namespace = false

  # 대규모 차트(CRD 포함)이므로 타임아웃을 넉넉히 잡습니다.
  timeout = 600

  # ── Prometheus 스토리지 ─────────────────────────────────────────────
  # 메트릭 데이터를 EBS gp3 볼륨에 영구 보존합니다.
  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName"
    value = kubernetes_storage_class_v1.gp3.metadata[0].name
  }
  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.accessModes[0]"
    value = "ReadWriteOnce"
  }
  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage"
    value = "10Gi"
  }
  # dev 환경: 메트릭 15일 보존 (프로덕션은 30d 이상 권장)
  set {
    name  = "prometheus.prometheusSpec.retention"
    value = "15d"
  }

  # ── Grafana 스토리지 ────────────────────────────────────────────────
  # 대시보드 설정, 플러그인 등을 EBS에 영구 보존합니다.
  set {
    name  = "grafana.persistence.enabled"
    value = "true"
  }
  set {
    name  = "grafana.persistence.storageClassName"
    value = kubernetes_storage_class_v1.gp3.metadata[0].name
  }
  set {
    name  = "grafana.persistence.size"
    value = "5Gi"
  }

  # ── Grafana 관리자 계정 ─────────────────────────────────────────────
  set_sensitive {
    name  = "grafana.adminUser"
    value = "admin"
  }
  set_sensitive {
    name  = "grafana.adminPassword"
    value = var.grafana_admin_password
  }

  # ── 서비스 접근 방식 ────────────────────────────────────────────────
  # ClusterIP: kubectl port-forward로 로컬에서 접근
  # 외부 공개가 필요하면 "LoadBalancer"로 변경 (ALB 비용 발생)
  set {
    name  = "grafana.service.type"
    value = "ClusterIP"
  }

  # ── 불필요한 컴포넌트 비활성화 ──────────────────────────────────────
  # AlertManager: Slack/Email 알림 발송 담당 — Pod 모니터링에 불필요
  set {
    name  = "alertmanager.enabled"
    value = "false"
  }
  # Node Exporter: EC2 노드의 CPU/디스크/네트워크 수집 DaemonSet — 활성화 유지

  depends_on = [
    module.eks,
    kubernetes_storage_class_v1.gp3,
  ]
}
