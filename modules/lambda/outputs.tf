output "image_resize_function_arn" {
  description = "이미지 리사이징 Lambda ARN"
  value       = aws_lambda_function.image_resize.arn
}

output "image_resize_function_name" {
  description = "이미지 리사이징 Lambda 함수명"
  value       = aws_lambda_function.image_resize.function_name
}

output "sns_notify_function_arn" {
  description = "SNS 알림 Lambda ARN"
  value       = aws_lambda_function.sns_notify.arn
}

output "sns_notify_function_name" {
  description = "SNS 알림 Lambda 함수명"
  value       = aws_lambda_function.sns_notify.function_name
}

output "function_names" {
  description = "Lambda 함수명 리스트 — CloudWatch 모니터링용"
  value = [
    aws_lambda_function.image_resize.function_name,
    aws_lambda_function.sns_notify.function_name,
  ]
}
