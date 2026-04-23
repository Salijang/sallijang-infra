locals {
  name_prefix = "${var.project_name}-${var.environment}"

  # Trust Policy에 사용: "https://" 제거한 OIDC 호스트
  oidc_host = replace(var.oidc_issuer_url, "https://", "")

  # Secrets Manager ARN 패턴 (프로젝트 전용 시크릿)
  secrets_arn_pattern = "arn:aws:secretsmanager:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:secret:${local.name_prefix}-*"
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# ── Trust Policy 헬퍼 ─────────────────────────────────────────────────
# 각 ServiceAccount용 Trust Policy를 생성하는 로컬 함수 역할
locals {
  trust_policy = {
    for sa_name in [
      "sallijang-order-sa",
      "sallijang-product-sa",
      "sallijang-notify-sa", # [추가] notify 서비스 IRSA 역할 신설에 따라 Trust Policy 대상에 포함
      "sallijang-user-sa",
      "sallijang-frontend-sa",
    ] : sa_name => jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.oidc_host}:sub" = "system:serviceaccount:${var.kubernetes_namespace}:${sa_name}"
            "${local.oidc_host}:aud" = "sts.amazonaws.com"
          }
        }
      }]
    })
  }
}

# ═══════════════════════════════════════════════════════════════════════
# 1. sallijang-order-sa
#    - SQS: SendMessage, ReceiveMessage, DeleteMessage
#    - SNS: Publish
#    - Secrets Manager: GetSecretValue
#    - [추가] RDS Proxy IAM Auth: order 서비스가 RDS Proxy에 IAM 토큰으로 접속하므로 추가
# ═══════════════════════════════════════════════════════════════════════
resource "aws_iam_role" "order" {
  name               = "${local.name_prefix}-order-sa-role"
  assume_role_policy = local.trust_policy["sallijang-order-sa"]

  tags = {
    Name        = "${local.name_prefix}-order-sa-role"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_policy" "order" {
  name = "${local.name_prefix}-order-sa-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SQSAccess"
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
        ]
        Resource = [
          var.sqs_queue_arn,
          var.sqs_dlq_arn,
        ]
      },
      {
        Sid      = "SNSPublish"
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = [var.sns_topic_arn]
      },
      {
        Sid      = "SecretsManagerRead"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = [local.secrets_arn_pattern]
      },
      {
        Sid      = "RDSProxyIAMAuth"
        Effect   = "Allow"
        Action   = ["rds-db:connect"]
        Resource = ["arn:aws:rds-db:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:dbuser:*/${var.db_username}"]
      },
    ]
  })

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy_attachment" "order" {
  role       = aws_iam_role.order.name
  policy_arn = aws_iam_policy.order.arn
}

# ═══════════════════════════════════════════════════════════════════════
# 2. sallijang-product-sa
#    - S3: PutObject, GetObject, DeleteObject (images 버킷 한정)
#    - Secrets Manager: GetSecretValue
#    - [추가] RDS Proxy IAM Auth: product 서비스가 RDS Proxy에 IAM 토큰으로 접속하므로 추가
# ═══════════════════════════════════════════════════════════════════════
resource "aws_iam_role" "product" {
  name               = "${local.name_prefix}-product-sa-role"
  assume_role_policy = local.trust_policy["sallijang-product-sa"]

  tags = {
    Name        = "${local.name_prefix}-product-sa-role"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_policy" "product" {
  name = "${local.name_prefix}-product-sa-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3ImagesBucketAccess"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
        ]
        # 버킷 자체 + 객체 경로 모두 포함
        Resource = [
          var.image_bucket_arn,
          "${var.image_bucket_arn}/*",
        ]
      },
      {
        Sid      = "SecretsManagerRead"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = [local.secrets_arn_pattern]
      },
      {
        Sid      = "RDSProxyIAMAuth"
        Effect   = "Allow"
        Action   = ["rds-db:connect"]
        Resource = ["arn:aws:rds-db:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:dbuser:*/${var.db_username}"]
      },
    ]
  })

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy_attachment" "product" {
  role       = aws_iam_role.product.name
  policy_arn = aws_iam_policy.product.arn
}

# ═══════════════════════════════════════════════════════════════════════
# 3. sallijang-notify-sa  [신규 추가]
#    notify 서비스가 처음에는 IAM 역할 없이 배포되어 AssumeRoleWithWebIdentity 오류 발생.
#    user/product/order와 동일하게 IRSA 역할을 신설하고 RDS Proxy 접근 권한 부여.
#    - RDS Proxy IAM Auth
#    - Secrets Manager: GetSecretValue
# ═══════════════════════════════════════════════════════════════════════
resource "aws_iam_role" "notify" {
  name               = "${local.name_prefix}-notify-sa-role"
  assume_role_policy = local.trust_policy["sallijang-notify-sa"]

  tags = {
    Name        = "${local.name_prefix}-notify-sa-role"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_policy" "notify" {
  name = "${local.name_prefix}-notify-sa-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "SecretsManagerRead"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = [local.secrets_arn_pattern]
      },
      {
        Sid      = "RDSProxyIAMAuth"
        Effect   = "Allow"
        Action   = ["rds-db:connect"]
        Resource = ["arn:aws:rds-db:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:dbuser:*/${var.db_username}"]
      },
    ]
  })

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy_attachment" "notify" {
  role       = aws_iam_role.notify.name
  policy_arn = aws_iam_policy.notify.arn
}

# ═══════════════════════════════════════════════════════════════════════
# 4. sallijang-user-sa
#    - Cognito: cognito-idp:*
#    - Secrets Manager: GetSecretValue
#    - [추가] RDS Proxy IAM Auth: user 서비스도 RDS Proxy 경유 접속이므로 통일
# ═══════════════════════════════════════════════════════════════════════
resource "aws_iam_role" "user" {
  name               = "${local.name_prefix}-user-sa-role"
  assume_role_policy = local.trust_policy["sallijang-user-sa"]

  tags = {
    Name        = "${local.name_prefix}-user-sa-role"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_policy" "user" {
  name = "${local.name_prefix}-user-sa-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "CognitoAccess"
        Effect   = "Allow"
        Action   = ["cognito-idp:*"]
        Resource = ["*"]
      },
      {
        Sid      = "SecretsManagerRead"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = [local.secrets_arn_pattern]
      },
      {
        Sid      = "RDSProxyIAMAuth"
        Effect   = "Allow"
        Action   = ["rds-db:connect"]
        Resource = ["arn:aws:rds-db:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:dbuser:*/${var.db_username}"]
      },
    ]
  })

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy_attachment" "user" {
  role       = aws_iam_role.user.name
  policy_arn = aws_iam_policy.user.arn
}

# ═══════════════════════════════════════════════════════════════════════
# 4. sallijang-frontend-sa
#    - CloudWatch Logs (최소 권한)
# ═══════════════════════════════════════════════════════════════════════
resource "aws_iam_role" "frontend" {
  name               = "${local.name_prefix}-frontend-sa-role"
  assume_role_policy = local.trust_policy["sallijang-frontend-sa"]

  tags = {
    Name        = "${local.name_prefix}-frontend-sa-role"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_policy" "frontend" {
  name = "${local.name_prefix}-frontend-sa-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogsWrite"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
        ]
        Resource = [
          "arn:aws:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:/aws/eks/${local.name_prefix}*",
          "arn:aws:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:/aws/eks/${local.name_prefix}*:*",
        ]
      },
    ]
  })

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy_attachment" "frontend" {
  role       = aws_iam_role.frontend.name
  policy_arn = aws_iam_policy.frontend.arn
}
