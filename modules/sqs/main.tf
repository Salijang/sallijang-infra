locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ── Dead Letter Queue ─────────────────────────────────────────────────
resource "aws_sqs_queue" "dlq" {
  name = "${local.name_prefix}-reservation-dlq"

  # DLQ는 메시지를 오래 보관 (14일) — 실패 원인 분석용
  message_retention_seconds = 1209600

  sqs_managed_sse_enabled = true

  tags = { Name = "${local.name_prefix}-reservation-dlq" }
}

# ── 예약 처리 메인 큐 ──────────────────────────────────────────────────
resource "aws_sqs_queue" "main" {
  name = "${local.name_prefix}-reservation"

  visibility_timeout_seconds = var.visibility_timeout_seconds
  message_retention_seconds  = var.message_retention_seconds

  # 3회 수신 실패 시 DLQ로 이동
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = var.max_receive_count
  })

  sqs_managed_sse_enabled = true

  tags = { Name = "${local.name_prefix}-reservation" }
}

# DLQ에서 메인 큐로 재처리 허용 (redrive allow policy)
resource "aws_sqs_queue_redrive_allow_policy" "dlq" {
  queue_url = aws_sqs_queue.dlq.id

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.main.arn]
  })
}

# ── 큐 접근 정책: SNS 발행 허용 ───────────────────────────────────────
# allowed_sns_topic_arns 이 비어 있으면 정책 생성 생략
resource "aws_sqs_queue_policy" "main" {
  count     = length(var.allowed_sns_topic_arns) > 0 ? 1 : 0
  queue_url = aws_sqs_queue.main.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowSNSPublish"
      Effect    = "Allow"
      Principal = { Service = "sns.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.main.arn
      Condition = {
        ArnEquals = {
          "aws:SourceArn" = var.allowed_sns_topic_arns
        }
      }
    }]
  })
}
