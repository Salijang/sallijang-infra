locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ── Security Group ────────────────────────────────────────────────────
resource "aws_security_group" "lambda" {
  count       = var.deploy_lambda ? 1 : 0
  name        = "${local.name_prefix}-sg-lambda"
  description = "Lambda function security group"
  vpc_id      = var.vpc_id

  # Lambda는 인바운드 없음 — 이벤트 기반 호출
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name_prefix}-sg-lambda" }
}

# ── IAM Execution Role ────────────────────────────────────────────────
resource "aws_iam_role" "lambda" {
  count = var.deploy_lambda ? 1 : 0
  name  = "${local.name_prefix}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Name = "${local.name_prefix}-lambda-role" }
}

# VPC 접근 + CloudWatch Logs 기본 권한
resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  count      = var.deploy_lambda ? 1 : 0
  role       = aws_iam_role.lambda[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# 서비스별 추가 권한
resource "aws_iam_role_policy" "lambda" {
  count = var.deploy_lambda ? 1 : 0
  name  = "${local.name_prefix}-lambda-policy"
  role  = aws_iam_role.lambda[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3ImageAccess"
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject"]
        Resource = ["${var.image_bucket_arn}/*"]
      },
      {
        Sid      = "SNSPublish"
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = [var.sns_topic_arn]
      }
    ]
  })
}

# ── Lambda 1: 이미지 리사이징 ─────────────────────────────────────────
# S3 products/ 경로에 .jpg 업로드 시 자동 트리거 → 썸네일 생성
resource "aws_lambda_function" "image_resize" {
  count         = var.deploy_lambda ? 1 : 0
  function_name = "${local.name_prefix}-image-resize"
  role          = aws_iam_role.lambda[0].arn
  handler       = var.image_resize_handler
  runtime       = var.runtime
  timeout       = var.timeout
  memory_size   = var.memory_size

  s3_bucket = var.code_s3_bucket
  s3_key    = var.image_resize_code_s3_key

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [aws_security_group.lambda[0].id]
  }

  environment {
    variables = {
      BUCKET_NAME = var.image_bucket_name
    }
  }

  tags = { Name = "${local.name_prefix}-image-resize" }
}

# S3가 Lambda를 호출할 수 있도록 리소스 기반 정책 추가
resource "aws_lambda_permission" "s3_invoke" {
  count         = var.deploy_lambda ? 1 : 0
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.image_resize[0].function_name
  principal     = "s3.amazonaws.com"
  source_arn    = var.image_bucket_arn
}

# S3 이벤트 → Lambda 트리거
resource "aws_s3_bucket_notification" "image_upload" {
  count  = var.deploy_lambda ? 1 : 0
  bucket = var.image_bucket_name

  lambda_function {
    lambda_function_arn = aws_lambda_function.image_resize[0].arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "products/"
  }

  depends_on = [aws_lambda_permission.s3_invoke]
}

# ── Lambda 2: SNS 알림 처리 ───────────────────────────────────────────
# SNS 토픽 구독 → 카카오 알림톡 / Slack 외부 API 호출
resource "aws_lambda_function" "sns_notify" {
  count         = var.deploy_lambda ? 1 : 0
  function_name = "${local.name_prefix}-sns-notify"
  role          = aws_iam_role.lambda[0].arn
  handler       = var.sns_notify_handler
  runtime       = var.sns_notify_runtime
  timeout       = var.timeout
  memory_size   = var.memory_size

  s3_bucket = var.code_s3_bucket
  s3_key    = var.sns_notify_code_s3_key

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [aws_security_group.lambda[0].id]
  }

  environment {
    variables = {
      SNS_TOPIC_ARN = var.sns_topic_arn
    }
  }

  tags = { Name = "${local.name_prefix}-sns-notify" }
}

# SNS가 Lambda를 호출할 수 있도록 리소스 기반 정책 추가
resource "aws_lambda_permission" "sns_invoke" {
  count         = var.deploy_lambda ? 1 : 0
  statement_id  = "AllowSNSInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.sns_notify[0].function_name
  principal     = "sns.amazonaws.com"
  source_arn    = var.sns_topic_arn
}

# SNS 토픽 → Lambda 구독 등록
resource "aws_sns_topic_subscription" "lambda_notify" {
  count     = var.deploy_lambda ? 1 : 0
  topic_arn = var.sns_topic_arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.sns_notify[0].arn
}
