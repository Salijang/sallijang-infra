locals {
  oidc_issuer_host = replace(module.eks.oidc_issuer_url, "https://", "")
}

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

resource "aws_iam_role" "grafana_cloudwatch" {
  name = "${var.project_name}-${var.environment}-grafana-cloudwatch-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = module.eks.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_issuer_host}:sub" = "system:serviceaccount:default:kube-prometheus-stack-grafana"
          "${local.oidc_issuer_host}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = { Name = "${var.project_name}-${var.environment}-grafana-cloudwatch-role" }
}

resource "aws_iam_policy" "grafana_cloudwatch" {
  name = "${var.project_name}-${var.environment}-grafana-cloudwatch-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "CloudWatchRead"
      Effect = "Allow"
      Action = [
        "cloudwatch:DescribeAlarms",
        "cloudwatch:DescribeAlarmsForMetric",
        "cloudwatch:DescribeAlarmHistory",
        "cloudwatch:GetMetricData",
        "cloudwatch:GetMetricStatistics",
        "cloudwatch:ListMetrics",
        "logs:DescribeLogGroups",
        "logs:GetLogGroupFields",
        "logs:StartQuery",
        "logs:StopQuery",
        "logs:GetQueryResults",
        "logs:GetLogEvents",
        "logs:FilterLogEvents",
        "ec2:DescribeRegions",
        "ec2:DescribeInstances",
        "ec2:DescribeTags",
        "tag:GetResources",
      ]
      Resource = ["*"]
    }]
  })

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy_attachment" "grafana_cloudwatch" {
  role       = aws_iam_role.grafana_cloudwatch.name
  policy_arn = aws_iam_policy.grafana_cloudwatch.arn
}

resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name             = module.eks.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  service_account_role_arn = aws_iam_role.ebs_csi_driver.arn

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [
    module.eks,
    aws_iam_role_policy_attachment.ebs_csi_driver,
  ]

  tags = { Name = "${var.project_name}-${var.environment}-ebs-csi-driver" }
}

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

resource "helm_release" "kube_prometheus_stack" {
  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = "65.1.1"
  namespace        = "default"
  create_namespace = false
  timeout          = 600

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
    value = "30Gi"
  }

  # prod: 메트릭 30일 보존
  set {
    name  = "prometheus.prometheusSpec.retention"
    value = "30d"
  }

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
    value = "10Gi"
  }

  set_sensitive {
    name  = "grafana.adminUser"
    value = "admin"
  }

  set_sensitive {
    name  = "grafana.adminPassword"
    value = var.grafana_admin_password
  }

  set {
    name  = "grafana.service.type"
    value = "ClusterIP"
  }

  set {
    name  = "grafana.serviceAccount.create"
    value = "true"
  }

  set {
    name  = "grafana.serviceAccount.name"
    value = "kube-prometheus-stack-grafana"
  }

  set {
    name  = "grafana.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.grafana_cloudwatch.arn
  }

  set {
    name  = "grafana.additionalDataSources[0].name"
    value = "CloudWatch"
  }

  set {
    name  = "grafana.additionalDataSources[0].uid"
    value = "cloudwatch"
  }

  set {
    name  = "grafana.additionalDataSources[0].type"
    value = "cloudwatch"
  }

  set {
    name  = "grafana.additionalDataSources[0].access"
    value = "proxy"
  }

  set {
    name  = "grafana.additionalDataSources[0].isDefault"
    value = "false"
  }

  set {
    name  = "grafana.additionalDataSources[0].editable"
    value = "true"
  }

  set {
    name  = "grafana.additionalDataSources[0].jsonData.authType"
    value = "default"
  }

  set {
    name  = "grafana.additionalDataSources[0].jsonData.defaultRegion"
    value = var.aws_region
  }

  # prod: AlertManager 활성화
  set {
    name  = "alertmanager.enabled"
    value = "true"
  }

  set {
    name  = "alertmanager.alertmanagerSpec.storage.volumeClaimTemplate.spec.storageClassName"
    value = kubernetes_storage_class_v1.gp3.metadata[0].name
  }

  set {
    name  = "alertmanager.alertmanagerSpec.storage.volumeClaimTemplate.spec.resources.requests.storage"
    value = "5Gi"
  }

  depends_on = [
    module.eks,
    kubernetes_storage_class_v1.gp3,
  ]
}

resource "kubernetes_config_map_v1" "grafana_dashboard_cloudwatch_core" {
  metadata {
    name      = "grafana-dashboard-cloudwatch-core"
    namespace = "default"
    labels = {
      grafana_dashboard = "1"
    }
    annotations = {
      grafana_folder = "CloudWatch"
    }
  }

  data = {
    "cloudwatch-core-metrics.json" = file("${path.module}/../../dashboards/cloudwatch-core-metrics.json")
  }

  depends_on = [helm_release.kube_prometheus_stack]
}

# ── CloudWatch (AWS 관리형 리소스 모니터링) ───────────────────────────
# K8s는 위 Prometheus/Grafana, AWS 리소스(RDS/Lambda/ALB/CloudFront)는 CloudWatch로 분리
module "cloudwatch" {
  source = "../../modules/cloudwatch"

  project_name = var.project_name
  environment  = var.environment

  aws_region = var.aws_region

  lambda_function_names = module.lambda.function_names
  log_retention_days    = 30

  enable_alarms = true
  sns_topic_arn = module.sns.topic_arn

  rds_instance_id   = module.rds.instance_id
  alb_arn_suffix    = module.alb.arn_suffix
  create_alb_alarms = true
  cloudfront_distribution_ids = [
    module.cloudfront.distribution_id,
    module.cloudfront.frontend_distribution_id,
  ]
  cloudfront_distribution_ids_by_name = {
    images   = module.cloudfront.distribution_id
    frontend = module.cloudfront.frontend_distribution_id
  }
}
