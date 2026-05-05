output "lambda_log_group_names" {
  description = "관리 중인 Lambda Log Group 이름 리스트"
  value       = [for lg in aws_cloudwatch_log_group.lambda : lg.name]
}

output "dashboard_name" {
  description = "통합 모니터링 대시보드 이름 (콘솔에서 직접 진입용)"
  value       = local.dashboard_enabled ? aws_cloudwatch_dashboard.main[0].dashboard_name : null
}
