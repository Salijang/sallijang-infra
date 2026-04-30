output "image_bucket_name" {
  description = "이미지 버킷 이름"
  value       = aws_s3_bucket.main["images"].id
}

output "image_bucket_arn" {
  description = "이미지 버킷 ARN"
  value       = aws_s3_bucket.main["images"].arn
}

output "image_bucket_regional_domain_name" {
  description = "이미지 버킷 리전 도메인명 — CloudFront Origin"
  value       = aws_s3_bucket.main["images"].bucket_regional_domain_name
}

output "frontend_bucket_name" {
  description = "프론트엔드 정적 파일 버킷 이름"
  value       = aws_s3_bucket.main["frontend"].id
}

output "frontend_bucket_arn" {
  description = "프론트엔드 버킷 ARN"
  value       = aws_s3_bucket.main["frontend"].arn
}

output "frontend_bucket_regional_domain_name" {
  description = "프론트엔드 버킷 리전 도메인명 — CloudFront Origin"
  value       = aws_s3_bucket.main["frontend"].bucket_regional_domain_name
}

output "log_bucket_name" {
  description = "로그 버킷 이름"
  value       = aws_s3_bucket.main["logs"].id
}

output "log_bucket_arn" {
  description = "로그 버킷 ARN"
  value       = aws_s3_bucket.main["logs"].arn
}

output "log_bucket_domain_name" {
  description = "로그 버킷 도메인명 (.s3.amazonaws.com) — CloudFront logging_config"
  value       = aws_s3_bucket.main["logs"].bucket_domain_name
}

output "backup_bucket_name" {
  description = "백업 버킷 이름"
  value       = aws_s3_bucket.main["backup"].id
}

output "backup_bucket_arn" {
  description = "백업 버킷 ARN"
  value       = aws_s3_bucket.main["backup"].arn
}
