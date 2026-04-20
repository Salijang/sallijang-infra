# argocd.tf

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  version          = "7.7.0" 

  # 중요: 워커 노드(ASG)가 다 뜨고 나서 설치를 시작해야 합니다.
  depends_on = [aws_autoscaling_group.node]

  # (선택) 외부에서 ArgoCD UI에 접속하고 싶다면 아래 주석을 해제하세요.
  # set {
  #   name  = "server.service.type"
  #   value = "LoadBalancer"
  # }

  # 로그인 비밀번호 확인법
  # kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
}