output "image_resize_function_arn" {
  description = "이미지 리사이징 Lambda ARN"
  value       = local.deploy_lambda ? aws_lambda_function.image_resize[0].arn : null
}

output "image_resize_function_name" {
  description = "이미지 리사이징 Lambda 함수명"
  value       = local.deploy_lambda ? aws_lambda_function.image_resize[0].function_name : null
}

output "sns_notify_function_arn" {
  description = "SNS 알림 Lambda ARN"
  value       = local.deploy_lambda ? aws_lambda_function.sns_notify[0].arn : null
}

output "sns_notify_function_name" {
  description = "SNS 알림 Lambda 함수명"
  value       = local.deploy_lambda ? aws_lambda_function.sns_notify[0].function_name : null
}

output "function_names" {
  description = "배포된 Lambda 함수명 리스트 — CloudWatch 모니터링에서 Log Group/Alarm 일괄 처리에 사용"
  value = local.deploy_lambda ? [
    aws_lambda_function.image_resize[0].function_name,
    aws_lambda_function.sns_notify[0].function_name,
  ] : []
}
