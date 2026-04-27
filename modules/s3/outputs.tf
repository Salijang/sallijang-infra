output "image_bucket_name" {
  description = "이미지 버킷 이름"
  value       = aws_s3_bucket.main["images"].id
}

output "image_bucket_arn" {
  description = "이미지 버킷 ARN — IRSA 정책에서 참조"
  value       = aws_s3_bucket.main["images"].arn
}

output "image_bucket_regional_domain_name" {
  description = "이미지 버킷 리전 도메인명 — CloudFront Origin에서 참조"
  value       = aws_s3_bucket.main["images"].bucket_regional_domain_name
}

output "log_bucket_name" {
  description = "로그 버킷 이름"
  value       = aws_s3_bucket.main["logs"].id
}

output "log_bucket_arn" {
  description = "로그 버킷 ARN"
  value       = aws_s3_bucket.main["logs"].arn
}

output "backup_bucket_name" {
  description = "백업 버킷 이름"
  value       = aws_s3_bucket.main["backup"].id
}

output "backup_bucket_arn" {
  description = "백업 버킷 ARN"
  value       = aws_s3_bucket.main["backup"].arn
}
