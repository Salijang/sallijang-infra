# karpenter.tf
# Karpenter 컨트롤러를 Helm으로 EKS 클러스터에 설치합니다.
#
# 선행 조건:
#   1. terraform apply (module.karpenter) 로 IAM/SQS 먼저 생성
#   2. aws eks update-kubeconfig --name <cluster-name> --region ap-northeast-2
#   3. terraform apply (이 파일)
#
# Karpenter v1.0 호환: EKS 1.25+

resource "helm_release" "karpenter" {
  name             = "karpenter"
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter"
  version          = "1.0.0"
  namespace        = "karpenter"
  create_namespace = true

  # EKS 완전 준비 후 적용 — 선행 리소스 직접 명시
  depends_on = [module.karpenter, module.eks]

  # 클러스터 이름 — NodePool/EC2NodeClass 디스커버리에 사용
  set {
    name  = "settings.clusterName"
    value = module.eks.cluster_name
  }

  # 스팟 인터럽션 SQS 큐 이름
  set {
    name  = "settings.interruptionQueue"
    value = module.karpenter.interruption_queue_name
  }

  # IRSA: Controller ServiceAccount에 IAM Role 주입
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.karpenter.controller_role_arn
  }

  # Controller 리소스 제한 (dev 환경 소형)
  set {
    name  = "controller.resources.requests.cpu"
    value = "100m"
  }

  set {
    name  = "controller.resources.requests.memory"
    value = "256Mi"
  }

  set {
    name  = "controller.resources.limits.cpu"
    value = "1"
  }

  set {
    name  = "controller.resources.limits.memory"
    value = "1Gi"
  }

  # replicas=2 로 고가용성 (ASG 노드 2대가 서로 다른 AZ에 있음)
  set {
    name  = "replicas"
    value = "2"
  }

  # 로그 레벨
  set {
    name  = "logLevel"
    value = "info"
  }
}
