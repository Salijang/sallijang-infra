locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ═══════════════════════════════════════════════════════════════════════
# 코드 패키징 & S3 업로드
# ═══════════════════════════════════════════════════════════════════════

# sharp는 native binary라 Linux x64 플랫폼으로 설치
resource "null_resource" "npm_install" {
  triggers = {
    package_json = filemd5("${var.image_resize_source_dir}/package.json")
    handler      = filemd5("${var.image_resize_source_dir}/handler.js")
  }

  provisioner "local-exec" {
    working_dir = var.image_resize_source_dir
    command     = "npm install"
    interpreter = ["bash", "-c"]
    environment = {
      npm_config_platform = "linux"
      npm_config_arch     = "x64"
    }
  }
}

data "archive_file" "image_resize" {
  depends_on  = [null_resource.npm_install]
  type        = "zip"
  source_dir  = var.image_resize_source_dir
  output_path = "${path.module}/image-resize.zip"
}

# sns-notify는 표준 라이브러리만 사용 — pip install 불필요
data "archive_file" "sns_notify" {
  type        = "zip"
  source_file = "${var.sns_notify_source_dir}/handler.py"
  output_path = "${path.module}/sns-notify.zip"
}

resource "aws_s3_object" "image_resize" {
  bucket = var.code_s3_bucket
  key    = "lambda/image-resize.zip"
  source = data.archive_file.image_resize.output_path
  etag   = data.archive_file.image_resize.output_md5
}

resource "aws_s3_object" "sns_notify" {
  bucket = var.code_s3_bucket
  key    = "lambda/sns-notify.zip"
  source = data.archive_file.sns_notify.output_path
  etag   = data.archive_file.sns_notify.output_md5
}

# ═══════════════════════════════════════════════════════════════════════
# Security Group & IAM
# ═══════════════════════════════════════════════════════════════════════

resource "aws_security_group" "lambda" {
  name        = "${local.name_prefix}-sg-lambda"
  description = "Lambda function security group"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name_prefix}-sg-lambda" }
}

resource "aws_iam_role" "lambda" {
  name = "${local.name_prefix}-lambda-role"

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

resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "lambda" {
  name = "${local.name_prefix}-lambda-policy"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "S3ImageAccess"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject"]
        Resource = ["${var.image_bucket_arn}/*"]
      },
      {
        Sid      = "SNSPublish"
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = [var.sns_topic_arn]
      },
      {
        Sid    = "DLQConsume"
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = [var.sqs_dlq_arn != "" ? var.sqs_dlq_arn : "arn:aws:sqs:*:*:placeholder"]
      }
    ]
  })
}

# ═══════════════════════════════════════════════════════════════════════
# Lambda 1: 이미지 리사이징
# ═══════════════════════════════════════════════════════════════════════

resource "aws_lambda_function" "image_resize" {
  function_name = "${local.name_prefix}-image-resize"
  role          = aws_iam_role.lambda.arn
  handler       = var.image_resize_handler
  runtime       = var.runtime
  timeout       = var.timeout
  memory_size   = var.memory_size

  s3_bucket        = var.code_s3_bucket
  s3_key           = aws_s3_object.image_resize.key
  source_code_hash = data.archive_file.image_resize.output_base64sha256

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      BUCKET_NAME = var.image_bucket_name
    }
  }

  tags = { Name = "${local.name_prefix}-image-resize" }
}

resource "aws_lambda_permission" "s3_invoke" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.image_resize.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = var.image_bucket_arn
}

resource "aws_s3_bucket_notification" "image_upload" {
  bucket = var.image_bucket_name

  lambda_function {
    lambda_function_arn = aws_lambda_function.image_resize.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "products/"
  }

  depends_on = [aws_lambda_permission.s3_invoke]
}

# ═══════════════════════════════════════════════════════════════════════
# Lambda 2: SNS 알림 처리
# ═══════════════════════════════════════════════════════════════════════

resource "aws_lambda_function" "sns_notify" {
  function_name = "${local.name_prefix}-sns-notify"
  role          = aws_iam_role.lambda.arn
  handler       = var.sns_notify_handler
  runtime       = var.sns_notify_runtime
  timeout       = var.timeout
  memory_size   = var.memory_size

  s3_bucket        = var.code_s3_bucket
  s3_key           = aws_s3_object.sns_notify.key
  source_code_hash = data.archive_file.sns_notify.output_base64sha256

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      SNS_TOPIC_ARN = var.sns_topic_arn
    }
  }

  tags = { Name = "${local.name_prefix}-sns-notify" }
}

resource "aws_lambda_permission" "sns_invoke" {
  statement_id  = "AllowSNSInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.sns_notify.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = var.sns_topic_arn
}

resource "aws_sns_topic_subscription" "lambda_notify" {
  topic_arn = var.sns_topic_arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.sns_notify.arn
}

resource "aws_lambda_event_source_mapping" "dlq_trigger" {
  count = var.sqs_dlq_arn != "" ? 1 : 0

  event_source_arn = var.sqs_dlq_arn
  function_name    = aws_lambda_function.sns_notify.arn

  batch_size                         = 1
  maximum_batching_window_in_seconds = 0

  function_response_types = ["ReportBatchItemFailures"]
}
