# GitHub Actions OIDC Keyless 인증
# AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY 없이 임시 크레덴셜을 발급합니다.
#
# 적용 방법:
#   cd bootstrap && terraform apply -target=aws_iam_openid_connect_provider.github -target=aws_iam_role.github_actions
#
# GitHub Actions workflow에서 사용:
#   permissions:
#     id-token: write
#     contents: read
#   steps:
#     - uses: aws-actions/configure-aws-credentials@v4
#       with:
#         role-to-assume: <github_actions_role_arn output 값>
#         aws-region: ap-northeast-2

# ── GitHub OIDC Provider ──────────────────────────────────────────────
# AWS는 token.actions.githubusercontent.com의 thumbprint를 자동으로 검증합니다.
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = { Name = "github-actions-oidc" }
}

# ── IAM Role: GitHub Actions가 Assume할 Role ──────────────────────────
resource "aws_iam_role" "github_actions" {
  name = "pickup-github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            # Salijang 조직 전체 리포지토리 허용 — 필요 시 특정 repo로 좁힐 것
            # 예: "repo:Salijang/sallijang-app:*"
            "token.actions.githubusercontent.com:sub" = "repo:Salijang/*:*"
          }
        }
      }
    ]
  })

  tags = { Name = "pickup-github-actions-role" }
}

# ── IAM Policy: CI/CD에 필요한 최소 권한 ─────────────────────────────
resource "aws_iam_role_policy" "github_actions" {
  name = "pickup-github-actions-policy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # ECR 로그인 (계정 전체 대상 — 특정 리소스로 제한 불가)
        Sid      = "ECRAuth"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = ["*"]
      },
      {
        # ECR 이미지 Push/Pull (pickup 관련 리포지토리만)
        Sid    = "ECRPush"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer"
        ]
        Resource = ["arn:aws:ecr:ap-northeast-2:594486941613:repository/pickup-*"]
      },
      {
        # EKS kubeconfig 업데이트 (kubectl/helm 배포용)
        Sid      = "EKSDescribe"
        Effect   = "Allow"
        Action   = ["eks:DescribeCluster"]
        Resource = ["arn:aws:eks:ap-northeast-2:594486941613:cluster/pickup-*"]
      },
      {
        # Lambda 코드 S3 업로드 (Lambda 배포 파이프라인용)
        Sid    = "LambdaCodeUpload"
        Effect = "Allow"
        Action = ["s3:PutObject", "s3:GetObject"]
        Resource = [
          "arn:aws:s3:::pickup-*-lambda/*"
        ]
      },
      {
        # 프론트엔드 S3 버킷 동기화
        Sid    = "FrontendS3Sync"
        Effect = "Allow"
        Action = ["s3:PutObject", "s3:GetObject", "s3:DeleteObject", "s3:ListBucket"]
        Resource = [
          "arn:aws:s3:::pickup-*-frontend",
          "arn:aws:s3:::pickup-*-frontend/*"
        ]
      },
      {
        # CloudFront 캐시 무효화
        Sid      = "CloudFrontInvalidation"
        Effect   = "Allow"
        Action   = ["cloudfront:CreateInvalidation"]
        Resource = ["arn:aws:cloudfront::594486941613:distribution/*"]
      },
      {
        # SSM에서 배포 설정값 읽기 (Distribution ID, 버킷명 등)
        Sid      = "SSMReadDeployConfig"
        Effect   = "Allow"
        Action   = ["ssm:GetParameter"]
        Resource = ["arn:aws:ssm:ap-northeast-2:594486941613:parameter/pickup/*"]
      },
      {
        # bootstrap terraform 자동화: 이 Role의 정책을 CI가 직접 업데이트할 수 있도록 허용
        Sid    = "IAMSelfManage"
        Effect = "Allow"
        Action = [
          "iam:GetRole",
          "iam:GetRolePolicy",
          "iam:PutRolePolicy",
          "iam:GetOpenIDConnectProvider",
          "iam:TagOpenIDConnectProvider"
        ]
        Resource = [
          "arn:aws:iam::594486941613:role/pickup-github-actions-role",
          "arn:aws:iam::594486941613:oidc-provider/token.actions.githubusercontent.com"
        ]
      },
      {
        # Terraform 원격 상태 버킷 ListBucket (terraform init 필수)
        Sid    = "TerraformStateList"
        Effect = "Allow"
        Action = ["s3:ListBucket"]
        Resource = [
          "arn:aws:s3:::pickup-prod-terraform-state",
          "arn:aws:s3:::pickup-dev-terraform-state"
        ]
      },
      {
        # Terraform 원격 상태 파일 읽기/쓰기
        Sid    = "TerraformStateReadWrite"
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = [
          "arn:aws:s3:::pickup-prod-terraform-state/*",
          "arn:aws:s3:::pickup-dev-terraform-state/*"
        ]
      },
      {
        # Terraform state lock (DynamoDB)
        Sid    = "TerraformStateLock"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = [
          "arn:aws:dynamodb:ap-northeast-2:594486941613:table/pickup-prod-terraform-lock",
          "arn:aws:dynamodb:ap-northeast-2:594486941613:table/pickup-dev-terraform-lock"
        ]
      }
    ]
  })
}

# ── Output ────────────────────────────────────────────────────────────
output "github_actions_role_arn" {
  description = "GitHub Actions workflow의 role-to-assume 값으로 사용"
  value       = aws_iam_role.github_actions.arn
}

output "github_oidc_provider_arn" {
  description = "GitHub OIDC Provider ARN"
  value       = aws_iam_openid_connect_provider.github.arn
}
