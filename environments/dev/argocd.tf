# argocd.tf

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  version          = "7.7.0"

  # 중요: 워커 노드(ASG)가 다 뜨고 나서 설치를 시작해야 합니다.
  depends_on = [module.eks]

  # (선택) 외부에서 ArgoCD UI에 접속하고 싶다면 아래 주석을 해제하세요.
  # set {
  #   name  = "server.service.type"
  #   value = "LoadBalancer"
  # }

  # 로그인 비밀번호 확인법
  # kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
}

# ── ArgoCD Applications ───────────────────────────────────────────────
# sallijang-manifest 레포의 base/<service> 경로를 자동 동기화.
# CI/CD가 이미지 태그를 업데이트하면 ArgoCD가 감지하여 자동 배포.
# frontend는 S3/CloudFront로 이관하여 제외.

locals {
  argocd_services = ["order", "product", "user", "notify", "ingress"]
}

resource "kubectl_manifest" "argocd_app" {
  for_each = toset(local.argocd_services)

  yaml_body = <<-YAML
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: sallijang-${each.key}
      namespace: argocd
    spec:
      project: default
      source:
        repoURL: https://github.com/Salijang/sallijang-manifest.git
        targetRevision: HEAD
        path: base/${each.key}
      destination:
        server: https://kubernetes.default.svc
        namespace: default
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
  YAML

  depends_on = [helm_release.argocd]
}