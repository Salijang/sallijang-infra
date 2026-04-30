# ── 이미지 CDN ───────────────────────────────────────────────────────

output "distribution_id" {
  description = "이미지 CloudFront Distribution ID"
  value       = aws_cloudfront_distribution.main.id
}

output "distribution_arn" {
  description = "이미지 CloudFront Distribution ARN"
  value       = aws_cloudfront_distribution.main.arn
}

output "distribution_domain_name" {
  description = "이미지 CloudFront 자동 할당 도메인명"
  value       = aws_cloudfront_distribution.main.domain_name
}

output "cdn_url" {
  description = "이미지 CDN URL"
  value       = "https://cdn.${var.domain_name}"
}

output "acm_certificate_arn" {
  description = "이미지 CDN ACM 인증서 ARN (us-east-1)"
  value       = aws_acm_certificate_validation.cdn.certificate_arn
}

# ── 프론트엔드 배포 ──────────────────────────────────────────────────

output "frontend_distribution_id" {
  description = "프론트엔드 CloudFront Distribution ID"
  value       = aws_cloudfront_distribution.frontend.id
}

output "frontend_distribution_arn" {
  description = "프론트엔드 CloudFront Distribution ARN"
  value       = aws_cloudfront_distribution.frontend.arn
}

output "frontend_distribution_domain_name" {
  description = "프론트엔드 CloudFront 자동 할당 도메인명"
  value       = aws_cloudfront_distribution.frontend.domain_name
}

output "frontend_url" {
  description = "프론트엔드 URL"
  value       = "https://app.${var.domain_name}"
}

output "frontend_certificate_arn" {
  description = "프론트엔드 ACM 인증서 ARN (us-east-1)"
  value       = aws_acm_certificate_validation.frontend.certificate_arn
}
