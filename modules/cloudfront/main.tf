locals {
  name_prefix = "${var.project_name}-${var.environment}"
  cdn_domain  = "cdn.${var.domain_name}"
  app_domain  = "app.${var.domain_name}"
}

# ── WAF Web ACL (CloudFront용 — us-east-1 필수) ───────────────────────
resource "aws_wafv2_web_acl" "cloudfront" {
  provider    = aws.us_east_1
  name        = "${local.name_prefix}-cloudfront-waf"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action { none {} }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-waf-common"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2

    override_action { none {} }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-waf-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${local.name_prefix}-cloudfront-waf"
    sampled_requests_enabled   = true
  }

  tags = { Name = "${local.name_prefix}-cloudfront-waf" }
}

# ═══════════════════════════════════════════════════════════════════════
# 이미지 CDN (기존)
# ═══════════════════════════════════════════════════════════════════════

# ── OAC ──────────────────────────────────────────────────────────────
resource "aws_cloudfront_origin_access_control" "main" {
  name                              = "${local.name_prefix}-oac-images"
  description                       = "OAC for ${local.name_prefix} images bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# ── ACM 인증서 (cdn.sallijang.shop, us-east-1) ────────────────────────
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

# ── 이미지 캐시 정책 (TTL 7일) ───────────────────────────────────────
resource "aws_cloudfront_cache_policy" "images" {
  name        = "${local.name_prefix}-images-cache-policy"
  min_ttl     = 0
  default_ttl = 604800
  max_ttl     = 604800

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

# ── 이미지 CloudFront Distribution ───────────────────────────────────
resource "aws_cloudfront_distribution" "main" {
  enabled             = true
  is_ipv6_enabled     = true
  price_class         = "PriceClass_200"
  aliases             = [local.cdn_domain]
  http_version        = "http2and3"
  wait_for_deployment = false
  web_acl_id          = aws_wafv2_web_acl.cloudfront.arn

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

  # 이미지 CDN 접근 로그 → logs 버킷 cloudfront/images/ prefix
  logging_config {
    bucket          = var.log_bucket_domain_name
    prefix          = "cloudfront/images/"
    include_cookies = false
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

  tags = { Name = "${local.name_prefix}-cloudfront-images" }
}

# ── 이미지 버킷 정책 — CloudFront OAC만 허용 ─────────────────────────
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

# ── Route53: cdn.sallijang.shop → 이미지 CloudFront ──────────────────
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

# ═══════════════════════════════════════════════════════════════════════
# 프론트엔드 배포 (신규)
# ═══════════════════════════════════════════════════════════════════════

# ── Frontend OAC ─────────────────────────────────────────────────────
resource "aws_cloudfront_origin_access_control" "frontend" {
  name                              = "${local.name_prefix}-oac-frontend"
  description                       = "OAC for ${local.name_prefix} frontend bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# ── ACM 인증서 (app.sallijang.shop, us-east-1) ────────────────────────
resource "aws_acm_certificate" "frontend" {
  provider          = aws.us_east_1
  domain_name       = local.app_domain
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = { Name = "${local.name_prefix}-acm-frontend" }
}

resource "aws_route53_record" "frontend_acm_validation" {
  for_each = {
    for dvo in aws_acm_certificate.frontend.domain_validation_options : dvo.domain_name => {
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

resource "aws_acm_certificate_validation" "frontend" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.frontend.arn
  validation_record_fqdns = [for r in aws_route53_record.frontend_acm_validation : r.fqdn]
}

# ── 캐시 정책: HTML (index.html) — 5분 TTL ───────────────────────────
# SPA에서 index.html은 새 배포 시 빠르게 갱신되어야 함
resource "aws_cloudfront_cache_policy" "frontend_html" {
  name        = "${local.name_prefix}-frontend-html-cache-policy"
  min_ttl     = 0
  default_ttl = 300
  max_ttl     = 300

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

# ── 캐시 정책: 정적 자산 — 1년 TTL ──────────────────────────────────
# /assets/* 는 빌드 시 파일명에 해시가 포함되어 캐시 무효화 불필요
resource "aws_cloudfront_cache_policy" "frontend_assets" {
  name        = "${local.name_prefix}-frontend-assets-cache-policy"
  min_ttl     = 0
  default_ttl = 31536000
  max_ttl     = 31536000

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

# ── Frontend CloudFront Distribution ─────────────────────────────────
resource "aws_cloudfront_distribution" "frontend" {
  enabled             = true
  is_ipv6_enabled     = true
  price_class         = "PriceClass_200"
  aliases             = [local.app_domain]
  http_version        = "http2and3"
  default_root_object = "index.html"
  wait_for_deployment = false
  web_acl_id          = aws_wafv2_web_acl.cloudfront.arn

  origin {
    domain_name              = var.frontend_bucket_regional_domain_name
    origin_id                = "s3-frontend"
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
  }

  # 기본 동작: HTML / SPA 루트 (짧은 캐시)
  default_cache_behavior {
    target_origin_id       = "s3-frontend"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    cache_policy_id        = aws_cloudfront_cache_policy.frontend_html.id
  }

  # /assets/* — 해시 파일명 자산 (장기 캐시)
  ordered_cache_behavior {
    path_pattern           = "/assets/*"
    target_origin_id       = "s3-frontend"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    cache_policy_id        = aws_cloudfront_cache_policy.frontend_assets.id
  }

  # SPA 라우팅 지원: S3 403/404 → index.html 200 응답
  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 0
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 0
  }

  # 프론트엔드 접근 로그 → logs 버킷 cloudfront/frontend/ prefix
  logging_config {
    bucket          = var.log_bucket_domain_name
    prefix          = "cloudfront/frontend/"
    include_cookies = false
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.frontend.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = { Name = "${local.name_prefix}-cloudfront-frontend" }
}

# ── Frontend 버킷 정책 — Frontend CloudFront OAC만 허용 ──────────────
resource "aws_s3_bucket_policy" "frontend_oac" {
  bucket = var.frontend_bucket_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontFrontendOAC"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${var.frontend_bucket_arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.frontend.arn
          }
        }
      }
    ]
  })
}

# ── Route53: app.sallijang.shop → Frontend CloudFront ─────────────────
resource "aws_route53_record" "frontend" {
  zone_id = var.hosted_zone_id
  name    = local.app_domain
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.frontend.domain_name
    zone_id                = aws_cloudfront_distribution.frontend.hosted_zone_id
    evaluate_target_health = false
  }
}
