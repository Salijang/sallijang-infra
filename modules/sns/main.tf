locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ── SNS 토픽 ──────────────────────────────────────────────────────────
resource "aws_sns_topic" "main" {
  name = "${local.name_prefix}-notification"

  # 전송 실패 메시지 보관 (CloudWatch Logs)
  sqs_failure_feedback_role_arn    = aws_iam_role.sns_feedback.arn
  sqs_success_feedback_role_arn    = aws_iam_role.sns_feedback.arn
  sqs_success_feedback_sample_rate = 0 # 성공 로그는 비활성 (비용 절감)

  tags = { Name = "${local.name_prefix}-notification" }
}

# ── SNS → SQS 구독 ────────────────────────────────────────────────────
resource "aws_sns_topic_subscription" "sqs" {
  count = var.create_sqs_subscription ? 1 : 0

  topic_arn = aws_sns_topic.main.arn
  protocol  = "sqs"
  endpoint  = var.sqs_endpoint_arn

  # raw message delivery: SQS 컨슈머가 SNS 래퍼 없이 메시지 본문만 수신
  raw_message_delivery = true
}

# ── IAM: SNS 전송 실패 피드백 Role ────────────────────────────────────
resource "aws_iam_role" "sns_feedback" {
  name = "${local.name_prefix}-sns-feedback-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "sns.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Name = "${local.name_prefix}-sns-feedback-role" }
}

resource "aws_iam_role_policy_attachment" "sns_feedback" {
  role       = aws_iam_role.sns_feedback.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonSNSRole"
}
