locals {
  name_prefix = "${var.project_name}-${var.environment}"

  buckets = {
    images = {
      name        = "${local.name_prefix}-images"
      versioning  = true
      expiration  = 0 # 만료 없음
    }
    logs = {
      name        = "${local.name_prefix}-logs"
      versioning  = false
      expiration  = var.log_expiration_days
    }
    backup = {
      name        = "${local.name_prefix}-backup"
      versioning  = true
      expiration  = 0
    }
  }
}

# ── S3 버킷 ───────────────────────────────────────────────────────────
resource "aws_s3_bucket" "main" {
  for_each = local.buckets

  bucket        = each.value.name
  force_destroy = var.force_destroy

  tags = { Name = each.value.name }
}

# ── 퍼블릭 접근 전면 차단 ─────────────────────────────────────────────
resource "aws_s3_bucket_public_access_block" "main" {
  for_each = local.buckets

  bucket                  = aws_s3_bucket.main[each.key].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ── 서버 사이드 암호화 (SSE-S3) ───────────────────────────────────────
resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  for_each = local.buckets

  bucket = aws_s3_bucket.main[each.key].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# ── 버전 관리 (images, backup 버킷) ──────────────────────────────────
resource "aws_s3_bucket_versioning" "main" {
  for_each = { for k, v in local.buckets : k => v if v.versioning }

  bucket = aws_s3_bucket.main[each.key].id

  versioning_configuration {
    status = "Enabled"
  }
}

# ── Lifecycle: 90일 후 Glacier 전환 ──────────────────────────────────
resource "aws_s3_bucket_lifecycle_configuration" "main" {
  for_each = local.buckets

  bucket = aws_s3_bucket.main[each.key].id

  rule {
    id     = "glacier-transition"
    status = "Enabled"

    transition {
      days          = var.glacier_transition_days
      storage_class = "GLACIER"
    }

    # 버전 관리 버킷: 이전 버전도 동일하게 전환
    dynamic "noncurrent_version_transition" {
      for_each = each.value.versioning ? [1] : []
      content {
        noncurrent_days = var.glacier_transition_days
        storage_class   = "GLACIER"
      }
    }
  }

  # 로그 버킷: 오래된 오브젝트 만료 처리
  dynamic "rule" {
    for_each = each.value.expiration > 0 ? [1] : []
    content {
      id     = "log-expiration"
      status = "Enabled"

      expiration {
        days = each.value.expiration
      }
    }
  }
}
