resource "helm_release" "karpenter" {
  name             = "karpenter"
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter"
  version          = "1.0.0"
  namespace        = "karpenter"
  create_namespace = true

  depends_on = [module.karpenter, module.eks]

  set {
    name  = "settings.clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "settings.interruptionQueue"
    value = module.karpenter.interruption_queue_name
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.karpenter.controller_role_arn
  }

  set {
    name  = "controller.resources.requests.cpu"
    value = "200m"
  }

  set {
    name  = "controller.resources.requests.memory"
    value = "512Mi"
  }

  set {
    name  = "controller.resources.limits.cpu"
    value = "2"
  }

  set {
    name  = "controller.resources.limits.memory"
    value = "2Gi"
  }

  set {
    name  = "replicas"
    value = "2"
  }

  set {
    name  = "logLevel"
    value = "info"
  }
}
