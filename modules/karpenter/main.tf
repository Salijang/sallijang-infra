locals {
  name_prefix = "${var.project_name}-${var.environment}"
  oidc_host   = replace(var.oidc_issuer_url, "https://", "")
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ═══════════════════════════════════════════════════════════════════════
# Karpenter Controller — IRSA
# ═══════════════════════════════════════════════════════════════════════

resource "aws_iam_role" "controller" {
  name = "${local.name_prefix}-karpenter-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = var.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_host}:sub" = "system:serviceaccount:karpenter:karpenter"
          "${local.oidc_host}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = { Name = "${local.name_prefix}-karpenter-controller" }
}

resource "aws_iam_policy" "controller" {
  name        = "${local.name_prefix}-karpenter-controller-policy"
  description = "Karpenter Controller 최소 권한 정책 (v1.x)"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # EC2 인스턴스 생성 (Fleet/RunInstances) — 리소스별 범위 제한
      {
        Sid    = "AllowScopedEC2InstanceActions"
        Effect = "Allow"
        Action = ["ec2:RunInstances", "ec2:CreateFleet"]
        Resource = [
          "arn:aws:ec2:${data.aws_region.current.id}::image/*",
          "arn:aws:ec2:${data.aws_region.current.id}::snapshot/*",
          "arn:aws:ec2:${data.aws_region.current.id}:*:spot-instances-request/*",
          "arn:aws:ec2:${data.aws_region.current.id}:*:security-group/*",
          "arn:aws:ec2:${data.aws_region.current.id}:*:subnet/*",
          "arn:aws:ec2:${data.aws_region.current.id}:*:launch-template/*",
          "arn:aws:ec2:${data.aws_region.current.id}:*:volume/*",
          "arn:aws:ec2:${data.aws_region.current.id}:*:network-interface/*",
          "arn:aws:ec2:${data.aws_region.current.id}:*:instance/*",
        ]
      },
      # Karpenter 관리 리소스 생성 — 클러스터/NodePool 태그 조건
      {
        Sid    = "AllowScopedEC2InstanceActionsWithTags"
        Effect = "Allow"
        Action = ["ec2:RunInstances", "ec2:CreateFleet", "ec2:CreateLaunchTemplate"]
        Resource = [
          "arn:aws:ec2:${data.aws_region.current.id}:*:fleet/*",
          "arn:aws:ec2:${data.aws_region.current.id}:*:instance/*",
          "arn:aws:ec2:${data.aws_region.current.id}:*:volume/*",
          "arn:aws:ec2:${data.aws_region.current.id}:*:network-interface/*",
          "arn:aws:ec2:${data.aws_region.current.id}:*:launch-template/*",
          "arn:aws:ec2:${data.aws_region.current.id}:*:spot-instances-request/*",
        ]
        Condition = {
          StringEquals = {
            "aws:RequestTag/kubernetes.io/cluster/${var.cluster_name}" = "owned"
          }
          StringLike = {
            "aws:RequestTag/karpenter.sh/nodepool" = "*"
          }
        }
      },
      # 생성 시 태그 부착
      {
        Sid    = "AllowScopedResourceCreationTagging"
        Effect = "Allow"
        Action = ["ec2:CreateTags"]
        Resource = [
          "arn:aws:ec2:${data.aws_region.current.id}:*:fleet/*",
          "arn:aws:ec2:${data.aws_region.current.id}:*:instance/*",
          "arn:aws:ec2:${data.aws_region.current.id}:*:volume/*",
          "arn:aws:ec2:${data.aws_region.current.id}:*:network-interface/*",
          "arn:aws:ec2:${data.aws_region.current.id}:*:launch-template/*",
          "arn:aws:ec2:${data.aws_region.current.id}:*:spot-instances-request/*",
        ]
        Condition = {
          StringEquals = {
            "aws:RequestTag/kubernetes.io/cluster/${var.cluster_name}" = "owned"
            "ec2:CreateAction" = ["RunInstances", "CreateFleet", "CreateLaunchTemplate"]
          }
          StringLike = {
            "aws:RequestTag/karpenter.sh/nodepool" = "*"
          }
        }
      },
      # 실행 중 인스턴스 태그 업데이트 (NodeClaim 이름 등)
      {
        Sid      = "AllowScopedResourceTagging"
        Effect   = "Allow"
        Action   = ["ec2:CreateTags"]
        Resource = ["arn:aws:ec2:${data.aws_region.current.id}:*:instance/*"]
        Condition = {
          StringEquals = {
            "aws:ResourceTag/kubernetes.io/cluster/${var.cluster_name}" = "owned"
          }
          StringLike = {
            "aws:ResourceTag/karpenter.sh/nodepool" = "*"
          }
          "ForAllValues:StringEquals" = {
            "aws:TagKeys" = ["karpenter.sh/nodeclaim", "Name"]
          }
        }
      },
      # Karpenter 관리 인스턴스/Launch Template 삭제
      {
        Sid    = "AllowScopedDeletion"
        Effect = "Allow"
        Action = ["ec2:TerminateInstances", "ec2:DeleteLaunchTemplate"]
        Resource = [
          "arn:aws:ec2:${data.aws_region.current.id}:*:instance/*",
          "arn:aws:ec2:${data.aws_region.current.id}:*:launch-template/*",
        ]
        Condition = {
          StringEquals = {
            "aws:ResourceTag/kubernetes.io/cluster/${var.cluster_name}" = "owned"
          }
          StringLike = {
            "aws:ResourceTag/karpenter.sh/nodepool" = "*"
          }
        }
      },
      # EC2 조회 (서브넷/SG 디스커버리, 스팟 가격 등)
      {
        Sid    = "AllowRegionalReadActions"
        Effect = "Allow"
        Action = [
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeImages",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSpotPriceHistory",
          "ec2:DescribeSubnets",
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = data.aws_region.current.id
          }
        }
      },
      # AMI 파라미터 조회 (SSM → EKS 최적화 AMI ID)
      {
        Sid      = "AllowSSMReadActions"
        Effect   = "Allow"
        Action   = ["ssm:GetParameter"]
        Resource = "arn:aws:ssm:${data.aws_region.current.id}::parameter/aws/service/*"
      },
      # 스팟 가격 데이터 (온디맨드 비용 계산)
      {
        Sid      = "AllowPricingReadActions"
        Effect   = "Allow"
        Action   = ["pricing:GetProducts"]
        Resource = "*"
      },
      # SQS 인터럽션 큐 소비
      {
        Sid    = "AllowInterruptionQueueActions"
        Effect = "Allow"
        Action = [
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl",
          "sqs:ReceiveMessage",
        ]
        Resource = aws_sqs_queue.interruption.arn
      },
      # 노드 Role을 EC2 서비스에 PassRole
      {
        Sid      = "AllowPassingInstanceRole"
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = aws_iam_role.node.arn
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "ec2.amazonaws.com"
          }
        }
      },
      # EC2NodeClass당 Instance Profile 자동 관리
      {
        Sid      = "AllowScopedInstanceProfileCreationActions"
        Effect   = "Allow"
        Action   = ["iam:CreateInstanceProfile"]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestTag/kubernetes.io/cluster/${var.cluster_name}" = "owned"
          }
          StringLike = {
            "aws:RequestTag/karpenter.k8s.aws/ec2nodeclass" = "*"
          }
        }
      },
      {
        Sid      = "AllowScopedInstanceProfileTagActions"
        Effect   = "Allow"
        Action   = ["iam:TagInstanceProfile"]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/kubernetes.io/cluster/${var.cluster_name}" = "owned"
            "aws:RequestTag/kubernetes.io/cluster/${var.cluster_name}"  = "owned"
          }
          StringLike = {
            "aws:ResourceTag/karpenter.k8s.aws/ec2nodeclass" = "*"
            "aws:RequestTag/karpenter.k8s.aws/ec2nodeclass"  = "*"
          }
        }
      },
      {
        Sid    = "AllowScopedInstanceProfileActions"
        Effect = "Allow"
        Action = [
          "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:DeleteInstanceProfile",
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/kubernetes.io/cluster/${var.cluster_name}" = "owned"
          }
          StringLike = {
            "aws:ResourceTag/karpenter.k8s.aws/ec2nodeclass" = "*"
          }
        }
      },
      {
        Sid      = "AllowInstanceProfileReadActions"
        Effect   = "Allow"
        Action   = ["iam:GetInstanceProfile"]
        Resource = "*"
      },
      # EKS 클러스터 메타데이터 조회
      {
        Sid      = "AllowAPIServerEndpointDiscovery"
        Effect   = "Allow"
        Action   = ["eks:DescribeCluster"]
        Resource = "arn:aws:eks:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:cluster/${var.cluster_name}"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "controller" {
  role       = aws_iam_role.controller.name
  policy_arn = aws_iam_policy.controller.arn
}

# ═══════════════════════════════════════════════════════════════════════
# Karpenter 노드 IAM Role + Instance Profile
# ═══════════════════════════════════════════════════════════════════════

resource "aws_iam_role" "node" {
  name = "${local.name_prefix}-karpenter-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Name = "${local.name_prefix}-karpenter-node-role" }
}

resource "aws_iam_role_policy_attachment" "node_worker" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_cni" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "node_ecr" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "node_ssm" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "node" {
  name = "${local.name_prefix}-karpenter-node-profile"
  role = aws_iam_role.node.name

  tags = { Name = "${local.name_prefix}-karpenter-node-profile" }
}

# EKS Access Entry: Karpenter 노드가 클러스터에 자동 조인
resource "aws_eks_access_entry" "karpenter_node" {
  cluster_name  = var.cluster_name
  principal_arn = aws_iam_role.node.arn
  type          = "EC2_LINUX"
}

# ═══════════════════════════════════════════════════════════════════════
# SQS 인터럽션 핸들러 큐
# ═══════════════════════════════════════════════════════════════════════

resource "aws_sqs_queue" "interruption" {
  name = "${local.name_prefix}-karpenter-interruption"

  # 스팟 인터럽션은 2분 전 통보 → 5분 보존이면 충분
  message_retention_seconds = 300
  sqs_managed_sse_enabled   = true

  tags = { Name = "${local.name_prefix}-karpenter-interruption" }
}

resource "aws_sqs_queue_policy" "interruption" {
  queue_url = aws_sqs_queue.interruption.url

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowEventBridgePublish"
      Effect = "Allow"
      Principal = {
        Service = "events.amazonaws.com"
      }
      Action   = "sqs:SendMessage"
      Resource = aws_sqs_queue.interruption.arn
    }]
  })
}

# ═══════════════════════════════════════════════════════════════════════
# EventBridge 규칙: EC2 이벤트 → SQS
# ═══════════════════════════════════════════════════════════════════════

resource "aws_cloudwatch_event_rule" "spot_interruption" {
  name        = "${local.name_prefix}-karpenter-spot-interruption"
  description = "Karpenter: 스팟 인터럽션 경고 수신"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Spot Instance Interruption Warning"]
  })
}

resource "aws_cloudwatch_event_target" "spot_interruption" {
  rule = aws_cloudwatch_event_rule.spot_interruption.name
  arn  = aws_sqs_queue.interruption.arn
}

resource "aws_cloudwatch_event_rule" "rebalance" {
  name        = "${local.name_prefix}-karpenter-rebalance"
  description = "Karpenter: 인스턴스 리밸런스 권고 수신"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Instance Rebalance Recommendation"]
  })
}

resource "aws_cloudwatch_event_target" "rebalance" {
  rule = aws_cloudwatch_event_rule.rebalance.name
  arn  = aws_sqs_queue.interruption.arn
}

resource "aws_cloudwatch_event_rule" "instance_state_change" {
  name        = "${local.name_prefix}-karpenter-instance-state"
  description = "Karpenter: EC2 인스턴스 상태 변경 수신"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Instance State-change Notification"]
  })
}

resource "aws_cloudwatch_event_target" "instance_state_change" {
  rule = aws_cloudwatch_event_rule.instance_state_change.name
  arn  = aws_sqs_queue.interruption.arn
}

resource "aws_cloudwatch_event_rule" "health_event" {
  name        = "${local.name_prefix}-karpenter-health-event"
  description = "Karpenter: AWS Health 이벤트 수신"

  event_pattern = jsonencode({
    source      = ["aws.health"]
    detail-type = ["AWS Health Event"]
  })
}

resource "aws_cloudwatch_event_target" "health_event" {
  rule = aws_cloudwatch_event_rule.health_event.name
  arn  = aws_sqs_queue.interruption.arn
}

# ═══════════════════════════════════════════════════════════════════════
# 서브넷 / 보안 그룹 — Karpenter 디스커버리 태그
# EC2NodeClass의 subnetSelectorTerms / securityGroupSelectorTerms가 참조
# ═══════════════════════════════════════════════════════════════════════

resource "aws_ec2_tag" "subnet_karpenter" {
  for_each    = { for idx, id in var.eks_subnet_ids : tostring(idx) => id }
  resource_id = each.value
  key         = "karpenter.sh/discovery"
  value       = var.cluster_name
}

resource "aws_ec2_tag" "node_sg_karpenter" {
  resource_id = var.node_sg_id
  key         = "karpenter.sh/discovery"
  value       = var.cluster_name
}
