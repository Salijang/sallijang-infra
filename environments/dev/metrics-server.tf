resource "helm_release" "metrics_server" {
  name             = "metrics-server"
  repository       = "https://kubernetes-sigs.github.io/metrics-server/"
  chart            = "metrics-server"
  version          = "3.12.1"
  namespace        = "kube-system"

  depends_on = [module.eks]

  set {
    name  = "args[0]"
    value = "--kubelet-insecure-tls"
  }
}
