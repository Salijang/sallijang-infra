output "controller_role_arn" {
  description = "Karpenter Controller IAM Role ARN — Helm values에 주입"
  value       = aws_iam_role.controller.arn
}

output "node_role_arn" {
  description = "Karpenter 노드 IAM Role ARN — EC2NodeClass spec.role에 사용"
  value       = aws_iam_role.node.arn
}

output "node_role_name" {
  description = "Karpenter 노드 IAM Role 이름 — EC2NodeClass spec.role에 사용"
  value       = aws_iam_role.node.name
}

output "node_instance_profile_name" {
  description = "Karpenter 노드 Instance Profile 이름"
  value       = aws_iam_instance_profile.node.name
}

output "interruption_queue_name" {
  description = "SQS 인터럽션 큐 이름 — Helm settings.interruptionQueue에 주입"
  value       = aws_sqs_queue.interruption.name
}

output "interruption_queue_url" {
  description = "SQS 인터럽션 큐 URL"
  value       = aws_sqs_queue.interruption.url
}

output "interruption_queue_arn" {
  description = "SQS 인터럽션 큐 ARN"
  value       = aws_sqs_queue.interruption.arn
}
