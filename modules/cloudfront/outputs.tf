output "distribution_id" {
  description = "CloudFront Distribution ID"
  value       = aws_cloudfront_distribution.main.id
}

output "distribution_arn" {
  description = "CloudFront Distribution ARN"
  value       = aws_cloudfront_distribution.main.arn
}

output "distribution_domain_name" {
  description = "CloudFront 자동 할당 도메인명 (xxx.cloudfront.net)"
  value       = aws_cloudfront_distribution.main.domain_name
}

output "cdn_url" {
  description = "CDN URL (Route53 레코드 기반)"
  value       = "https://cdn.${var.domain_name}"
}

output "acm_certificate_arn" {
  description = "us-east-1 ACM 인증서 ARN"
  value       = aws_acm_certificate_validation.cdn.certificate_arn
}
