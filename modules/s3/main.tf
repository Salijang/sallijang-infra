locals {
  name_prefix = "${var.project_name}-${var.environment}"

  all_buckets = {
    images   = { name = "${local.name_prefix}-images",   versioning = true }
    logs     = { name = "${local.name_prefix}-logs",     versioning = false }
    backup   = { name = "${local.name_prefix}-backup",   versioning = true }
    frontend = { name = "${local.name_prefix}-frontend", versioning = true }
  }

  # logs 버킷만 제외 — CloudFront log-delivery-write ACL을 위해 block_public_acls=false 필요
  strict_buckets = { for k, v in local.all_buckets : k => v if k != "logs" }

  # logs 버킷 prefix별 생명주기 정책
  log_prefixes = {
    alb = {
      prefix       = "alb/"
      glacier_days = var.alb_log_glacier_days
      expire_days  = var.alb_log_expire_days
    }
    cloudfront = {
      prefix       = "cloudfront/"
      glacier_days = var.cloudfront_log_glacier_days
      expire_days  = var.cloudfront_log_expire_days
    }
    application = {
      prefix       = "application/"
      glacier_days = var.application_log_glacier_days
      expire_days  = var.application_log_expire_days
    }
    vpc_flow = {
      prefix       = "vpc-flow/"
      glacier_days = var.vpc_flow_log_glacier_days
      expire_days  = var.vpc_flow_log_expire_days
    }
  }
}

# ── S3 버킷 ───────────────────────────────────────────────────────────
resource "aws_s3_bucket" "main" {
  for_each      = local.all_buckets
  bucket        = each.value.name
  force_destroy = var.force_destroy
  tags          = { Name = each.value.name }
}

# ── 퍼블릭 접근 완전 차단 (images, backup, frontend) ──────────────────
resource "aws_s3_bucket_public_access_block" "strict" {
  for_each                = local.strict_buckets
  bucket                  = aws_s3_bucket.main[each.key].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ── logs 버킷 접근 설정 ───────────────────────────────────────────────
# block_public_acls=false: CloudFront log-delivery-write ACL 허용
# ignore_public_acls=false: 해당 ACL이 실제로 적용되도록 설정
resource "aws_s3_bucket_public_access_block" "logs" {
  bucket                  = aws_s3_bucket.main["logs"].id
  block_public_acls       = false
  block_public_policy     = true
  ignore_public_acls      = false
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "logs" {
  bucket = aws_s3_bucket.main["logs"].id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }

  depends_on = [aws_s3_bucket_public_access_block.logs]
}

# CloudFront 로그 배포 서비스가 버킷에 쓸 수 있도록 ACL 부여
resource "aws_s3_bucket_acl" "logs" {
  bucket     = aws_s3_bucket.main["logs"].id
  acl        = "log-delivery-write"
  depends_on = [aws_s3_bucket_ownership_controls.logs]
}

# ── SSE-S3 암호화 ─────────────────────────────────────────────────────
resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  for_each = local.all_buckets
  bucket   = aws_s3_bucket.main[each.key].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# ── 버전 관리 ─────────────────────────────────────────────────────────
resource "aws_s3_bucket_versioning" "main" {
  for_each = { for k, v in local.all_buckets : k => v if v.versioning }
  bucket   = aws_s3_bucket.main[each.key].id

  versioning_configuration {
    status = "Enabled"
  }
}

# ── Lifecycle: images ─────────────────────────────────────────────────
# 현재 버전은 CloudFront로 서빙 중 → Glacier 이전 없음
# 이전 버전만 90일 후 Glacier → 365일 후 삭제
resource "aws_s3_bucket_lifecycle_configuration" "images" {
  bucket = aws_s3_bucket.main["images"].id

  rule {
    id     = "noncurrent-to-glacier"
    status = "Enabled"

    filter {}

    noncurrent_version_transition {
      noncurrent_days = 90
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = 365
    }
  }
}

# ── Lifecycle: frontend ───────────────────────────────────────────────
# 현재 버전은 CloudFront로 서빙 중 → Glacier 이전 없음
# 이전 버전은 최근 5개 보존, 30일 후 삭제 (배포 롤백 대비)
resource "aws_s3_bucket_lifecycle_configuration" "frontend" {
  bucket = aws_s3_bucket.main["frontend"].id

  rule {
    id     = "noncurrent-cleanup"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days           = 30
      newer_noncurrent_versions = 5
    }
  }
}

# ── Lifecycle: backup ─────────────────────────────────────────────────
# 30일 → Glacier IR (즉시 조회), 90일 → Glacier (아카이브)
# 이전 버전: 90일 후 Glacier → 180일 후 삭제
resource "aws_s3_bucket_lifecycle_configuration" "backup" {
  bucket = aws_s3_bucket.main["backup"].id

  rule {
    id     = "backup-to-glacier"
    status = "Enabled"

    filter {}

    transition {
      days          = 30
      storage_class = "GLACIER_IR"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    noncurrent_version_transition {
      noncurrent_days = 90
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = 180
    }
  }
}

# ── Lifecycle: logs — prefix별 차등 정책 ─────────────────────────────
#
# 로그 경로 구조:
#   alb/         → ALB 접근 로그 (ELB 서비스가 자동 적재)
#   cloudfront/  → CloudFront 접근 로그
#   application/ → 앱 로그 (FluentBit → S3)
#   vpc-flow/    → VPC Flow 로그
#
resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.main["logs"].id

  dynamic "rule" {
    for_each = local.log_prefixes
    content {
      id     = "${rule.key}-lifecycle"
      status = "Enabled"

      filter {
        prefix = rule.value.prefix
      }

      transition {
        days          = rule.value.glacier_days
        storage_class = "GLACIER_IR"
      }

      expiration {
        days = rule.value.expire_days
      }
    }
  }
}

# ── ALB 접근 로그 수신 버킷 정책 ─────────────────────────────────────
# ap-northeast-2 ELB 서비스 계정 ID: 600734575887
resource "aws_s3_bucket_policy" "logs_alb" {
  bucket     = aws_s3_bucket.main["logs"].id
  depends_on = [aws_s3_bucket_public_access_block.logs]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowALBAccessLogs"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::600734575887:root"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.main["logs"].arn}/alb/*"
      },
      {
        Sid    = "AllowDeliveryServiceCheck"
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.main["logs"].arn
      },
      {
        Sid    = "AllowDeliveryServicePut"
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.main["logs"].arn}/alb/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}
