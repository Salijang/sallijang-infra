# ingress.tf
# nginx Ingress Controller를 Helm으로 EKS 클러스터에 설치합니다.
#
# 트래픽 흐름:
#   ALB (443) → NodePort 30080 → nginx Ingress Controller → 경로별 Pod
#
# 선행 조건:
#   1. terraform apply (module.eks) 로 EKS 클러스터 먼저 생성
#   2. aws eks update-kubeconfig --name <cluster-name> --region ap-northeast-2
#   3. terraform apply (이 파일)
#
# K8s Ingress 리소스 적용:
#   kubectl apply -f k8s-manifests/ingress.yaml

resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = "4.10.1"
  namespace        = "ingress-nginx"
  create_namespace = true

  depends_on = [module.eks]

  # ALB Target Group이 NodePort 30080으로 포워딩하므로 동일 포트 고정
  set {
    name  = "controller.service.type"
    value = "NodePort"
  }

  set {
    name  = "controller.service.nodePorts.http"
    value = tostring(var.node_port)
  }

  # ALB 헬스체크(/health) 응답을 nginx가 직접 처리
  set {
    name  = "controller.config.server-snippet"
    value = "location /health { return 200 'healthy'; add_header Content-Type text/plain; }"
  }

  # X-Forwarded-For 헤더 신뢰 (ALB가 클라이언트 IP를 헤더로 전달)
  set {
    name  = "controller.config.use-forwarded-headers"
    value = "true"
  }

  # ALB에서 TLS 종단 처리 — nginx는 HTTP만 수신
  set {
    name  = "controller.config.ssl-redirect"
    value = "false"
  }

  # 복제본 2개 — AZ-a, AZ-c에 각 1개 배치
  set {
    name  = "controller.replicaCount"
    value = "2"
  }

  set {
    name  = "controller.resources.requests.cpu"
    value = "100m"
  }

  set {
    name  = "controller.resources.requests.memory"
    value = "128Mi"
  }

  set {
    name  = "controller.resources.limits.cpu"
    value = "500m"
  }

  set {
    name  = "controller.resources.limits.memory"
    value = "512Mi"
  }
}
