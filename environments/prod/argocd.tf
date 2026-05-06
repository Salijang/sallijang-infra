resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  version          = "7.7.0"

  depends_on = [module.eks]

  set {
    name  = "server.replicas"
    value = "2"
  }

  set {
    name  = "repoServer.replicas"
    value = "2"
  }
}

# ── ArgoCD Applications ───────────────────────────────────────────────
# sallijang-manifest 레포의 prod/<service> 경로를 자동 동기화.
# CI/CD가 이미지 태그를 업데이트하면 ArgoCD가 감지하여 자동 배포.

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
        path: prod/${each.key}
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
