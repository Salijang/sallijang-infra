output "topic_arn" {
  description = "SNS 토픽 ARN — SQS 큐 정책 및 IRSA에서 참조"
  value       = aws_sns_topic.main.arn
}

output "topic_name" {
  description = "SNS 토픽 이름"
  value       = aws_sns_topic.main.name
}
