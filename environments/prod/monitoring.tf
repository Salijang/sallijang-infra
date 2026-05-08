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

resource "aws_iam_role" "loki_s3" {
  name = "${var.project_name}-${var.environment}-loki-s3-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = module.eks.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_issuer_host}:sub" = "system:serviceaccount:default:loki"
          "${local.oidc_issuer_host}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = { Name = "${var.project_name}-${var.environment}-loki-s3-role" }
}

resource "aws_iam_policy" "loki_s3" {
  name = "${var.project_name}-${var.environment}-loki-s3-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "LokiS3ListBucket"
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = module.s3.log_bucket_arn
      },
      {
        Sid    = "LokiS3Objects"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
        ]
        Resource = "${module.s3.log_bucket_arn}/*"
      }
    ]
  })

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy_attachment" "loki_s3" {
  role       = aws_iam_role.loki_s3.name
  policy_arn = aws_iam_policy.loki_s3.arn
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
    name  = "grafana.sidecar.datasources.initDatasources"
    value = "true"
  }

  set {
    name  = "grafana.sidecar.datasources.skipReload"
    value = "false"
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

  set {
    name  = "grafana.additionalDataSources[1].name"
    value = "Loki"
  }

  set {
    name  = "grafana.additionalDataSources[1].uid"
    value = "loki"
  }

  set {
    name  = "grafana.additionalDataSources[1].type"
    value = "loki"
  }

  set {
    name  = "grafana.additionalDataSources[1].access"
    value = "proxy"
  }

  set {
    name  = "grafana.additionalDataSources[1].url"
    value = "http://loki-gateway.default.svc.cluster.local"
  }

  set {
    name  = "grafana.additionalDataSources[1].isDefault"
    value = "false"
  }

  set {
    name  = "grafana.additionalDataSources[1].editable"
    value = "true"
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

resource "helm_release" "loki" {
  name             = "loki"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "loki"
  version          = "6.24.0"
  namespace        = "default"
  create_namespace = false
  timeout          = 600

  values = [
    yamlencode({
      loki = {
        auth_enabled = false
        commonConfig = {
          replication_factor = 1
        }
        schemaConfig = {
          configs = [{
            from         = "2024-04-01"
            store        = "tsdb"
            object_store = "s3"
            schema       = "v13"
            index = {
              prefix = "loki_index_"
              period = "24h"
            }
          }]
        }
        storage_config = {
          aws = {
            region           = var.aws_region
            bucketnames      = module.s3.log_bucket_name
            s3forcepathstyle = false
          }
        }
        storage = {
          type = "s3"
          bucketNames = {
            chunks = module.s3.log_bucket_name
            ruler  = module.s3.log_bucket_name
          }
          s3 = {
            region = var.aws_region
          }
        }
        limits_config = {
          allow_structured_metadata = true
          volume_enabled            = true
          retention_period          = "720h"
        }
        compactor = {
          retention_enabled    = true
          delete_request_store = "s3"
        }
        ruler = {
          enable_api = true
          storage = {
            type = "s3"
            s3 = {
              region           = var.aws_region
              bucketnames      = module.s3.log_bucket_name
              s3forcepathstyle = false
            }
          }
        }
      }

      serviceAccount = {
        create = true
        name   = "loki"
        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.loki_s3.arn
        }
      }

      deploymentMode = "SingleBinary"

      singleBinary = {
        replicas = 1
        persistence = {
          enabled                        = true
          storageClass                   = kubernetes_storage_class_v1.gp3.metadata[0].name
          size                           = "30Gi"
          enableStatefulSetAutoDeletePVC = false
        }
      }

      backend = { replicas = 0 }
      read    = { replicas = 0 }
      write   = { replicas = 0 }

      ingester       = { replicas = 0 }
      querier        = { replicas = 0 }
      queryFrontend  = { replicas = 0 }
      queryScheduler = { replicas = 0 }
      distributor    = { replicas = 0 }
      compactor      = { replicas = 0 }
      indexGateway   = { replicas = 0 }
      bloomPlanner   = { replicas = 0 }
      bloomBuilder   = { replicas = 0 }
      bloomGateway   = { replicas = 0 }

      gateway = {
        enabled = true
        service = {
          type = "ClusterIP"
        }
      }

      chunksCache = {
        enabled = false
      }

      resultsCache = {
        enabled = false
      }

      minio = {
        enabled = false
      }
    })
  ]

  depends_on = [
    module.eks,
    kubernetes_storage_class_v1.gp3,
    aws_iam_role_policy_attachment.loki_s3,
  ]
}

resource "helm_release" "alloy" {
  name             = "alloy"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "alloy"
  version          = "0.11.0"
  namespace        = "default"
  create_namespace = false
  timeout          = 300

  values = [
    yamlencode({
      controller = {
        type = "daemonset"
      }

      alloy = {
        mounts = {
          varlog = true
        }
        configMap = {
          create  = true
          content = <<-EOT
            discovery.kubernetes "pods" {
              role = "pod"
            }

            discovery.relabel "pods" {
              targets = discovery.kubernetes.pods.targets

              rule {
                source_labels = ["__meta_kubernetes_namespace"]
                target_label  = "namespace"
              }

              rule {
                source_labels = ["__meta_kubernetes_pod_name"]
                target_label  = "pod"
              }

              rule {
                source_labels = ["__meta_kubernetes_pod_container_name"]
                target_label  = "container"
              }

              rule {
                source_labels = ["__meta_kubernetes_pod_label_app_kubernetes_io_name"]
                target_label  = "app"
              }

              rule {
                source_labels = ["__meta_kubernetes_pod_uid", "__meta_kubernetes_pod_container_name"]
                separator     = "/"
                target_label  = "__path__"
                replacement   = "/var/log/pods/*$1/*.log"
              }
            }

            local.file_match "pods" {
              path_targets = discovery.relabel.pods.output
            }

            loki.source.file "pods" {
              targets    = local.file_match.pods.targets
              forward_to = [loki.process.pods.receiver]
            }

            loki.process "pods" {
              stage.cri {}
              forward_to = [loki.write.default.receiver]
            }

            loki.write "default" {
              endpoint {
                url = "http://loki-gateway.default.svc.cluster.local/loki/api/v1/push"
              }
            }
          EOT
        }
      }
    })
  ]

  depends_on = [
    helm_release.loki,
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
