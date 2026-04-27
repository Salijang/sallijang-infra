locals {
  name_prefix = "${var.project_name}-${var.environment}"
  cdn_domain  = "cdn.${var.domain_name}"
}

# ── OAC (Origin Access Control) ───────────────────────────────────────
# S3 버킷에 직접 URL 접근을 차단하고 CloudFront 서명 요청만 허용
resource "aws_cloudfront_origin_access_control" "main" {
  name                              = "${local.name_prefix}-oac-images"
  description                       = "OAC for ${local.name_prefix} images bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# ── ACM 인증서 (us-east-1 — CloudFront 전용 리전) ─────────────────────
resource "aws_acm_certificate" "cdn" {
  provider          = aws.us_east_1
  domain_name       = local.cdn_domain
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = { Name = "${local.name_prefix}-acm-cdn" }
}

resource "aws_route53_record" "acm_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cdn.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id         = var.hosted_zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "cdn" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.cdn.arn
  validation_record_fqdns = [for r in aws_route53_record.acm_validation : r.fqdn]
}

# ── 이미지 캐시 정책 (TTL 7일, gzip + brotli 압축) ───────────────────
resource "aws_cloudfront_cache_policy" "images" {
  name        = "${local.name_prefix}-images-cache-policy"
  min_ttl     = 0
  default_ttl = 604800 # 7일
  max_ttl     = 604800 # 7일

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "none"
    }
    headers_config {
      header_behavior = "none"
    }
    query_strings_config {
      query_string_behavior = "none"
    }
    enable_accept_encoding_gzip   = true
    enable_accept_encoding_brotli = true
  }
}

# ── CloudFront Distribution ───────────────────────────────────────────
resource "aws_cloudfront_distribution" "main" {
  enabled             = true
  is_ipv6_enabled     = true
  price_class         = "PriceClass_200"
  aliases             = [local.cdn_domain]
  http_version        = "http2and3"
  wait_for_deployment = false

  origin {
    domain_name              = var.image_bucket_regional_domain_name
    origin_id                = "s3-images"
    origin_access_control_id = aws_cloudfront_origin_access_control.main.id
  }

  default_cache_behavior {
    target_origin_id       = "s3-images"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    cache_policy_id        = aws_cloudfront_cache_policy.images.id
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.cdn.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = { Name = "${local.name_prefix}-cloudfront" }
}

# ── S3 버킷 정책 — CloudFront OAC만 s3:GetObject 허용 ────────────────
# 이 정책으로 S3 직접 URL 접근이 차단되고 CloudFront 경유만 허용됨
resource "aws_s3_bucket_policy" "images_oac" {
  bucket = var.image_bucket_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontOAC"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${var.image_bucket_arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.main.arn
          }
        }
      }
    ]
  })
}

# ── Route53 A 레코드 (cdn.sallijang.shop → CloudFront) ────────────────
resource "aws_route53_record" "cdn" {
  zone_id = var.hosted_zone_id
  name    = local.cdn_domain
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.main.domain_name
    zone_id                = aws_cloudfront_distribution.main.hosted_zone_id
    evaluate_target_health = false
  }
}
