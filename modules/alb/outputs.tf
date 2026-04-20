output "alb_arn" {
  description = "ALB ARN"
  value       = aws_lb.main.arn
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "ALB hosted zone ID (for Route53 alias records)"
  value       = aws_lb.main.zone_id
}

output "target_group_arn" {
  description = "Target group ARN"
  value       = aws_lb_target_group.main.arn
}

output "https_listener_arn" {
  description = "HTTPS listener ARN (certificate_arn 미설정 시 null)"
  value       = length(aws_lb_listener.https) > 0 ? aws_lb_listener.https[0].arn : null
}

output "acm_certificate_arn" {
  description = "ACM certificate ARN (auto-create 시에만 값 있음)"
  value       = length(aws_acm_certificate.main) > 0 ? aws_acm_certificate.main[0].arn : var.certificate_arn
}

output "waf_web_acl_arn" {
  description = "WAF Web ACL ARN"
  value       = aws_wafv2_web_acl.main.arn
}
