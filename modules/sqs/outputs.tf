output "queue_url" {
  description = "예약 처리 SQS 큐 URL — 파드에서 메시지 수신 시 사용"
  value       = aws_sqs_queue.main.id
}

output "queue_arn" {
  description = "예약 처리 SQS 큐 ARN — SNS 구독 및 IRSA 정책에서 참조"
  value       = aws_sqs_queue.main.arn
}

output "queue_name" {
  description = "예약 처리 SQS 큐 이름"
  value       = aws_sqs_queue.main.name
}

output "dlq_url" {
  description = "DLQ URL"
  value       = aws_sqs_queue.dlq.id
}

output "dlq_arn" {
  description = "DLQ ARN"
  value       = aws_sqs_queue.dlq.arn
}
