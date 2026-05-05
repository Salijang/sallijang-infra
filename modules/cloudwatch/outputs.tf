output "lambda_log_group_names" {
  description = "관리 중인 Lambda Log Group 이름 리스트"
  value       = [for lg in aws_cloudwatch_log_group.lambda : lg.name]
}
