# bootstrap/main.tf
# Terraform remote state용 S3 버킷과 DynamoDB 테이블을 생성합니다.
# chicken-and-egg 문제로 인해 이 파일은 로컬 state로 별도 apply합니다.
# 생성 후 environments/dev/backend.tf의 S3 backend를 활성화하세요.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-2"

  default_tags {
    tags = {
      Project   = "pickup"
      ManagedBy = "Terraform"
    }
  }
}

# -------------------------------------------------------------------
# S3 버킷 – Terraform state 저장소
# -------------------------------------------------------------------

resource "aws_s3_bucket" "terraform_state" {
  bucket = "pickup-dev-terraform-state"
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    id     = "expire-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

# -------------------------------------------------------------------
# DynamoDB 테이블 – Terraform state 잠금
# -------------------------------------------------------------------

resource "aws_dynamodb_table" "terraform_lock" {
  name         = "pickup-dev-terraform-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

# -------------------------------------------------------------------
# S3 버킷 – Terraform state 저장소 (prod)
# -------------------------------------------------------------------

resource "aws_s3_bucket" "terraform_state_prod" {
  bucket = "pickup-prod-terraform-state"
}

resource "aws_s3_bucket_versioning" "terraform_state_prod" {
  bucket = aws_s3_bucket.terraform_state_prod.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state_prod" {
  bucket = aws_s3_bucket.terraform_state_prod.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state_prod" {
  bucket = aws_s3_bucket.terraform_state_prod.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "terraform_state_prod" {
  bucket = aws_s3_bucket.terraform_state_prod.id

  rule {
    id     = "expire-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

# -------------------------------------------------------------------
# DynamoDB 테이블 – Terraform state 잠금 (prod)
# -------------------------------------------------------------------

resource "aws_dynamodb_table" "terraform_lock_prod" {
  name         = "pickup-prod-terraform-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

# -------------------------------------------------------------------
# Outputs
# -------------------------------------------------------------------

output "dev_state_bucket_name" {
  value = aws_s3_bucket.terraform_state.bucket
}

output "dev_state_bucket_arn" {
  value = aws_s3_bucket.terraform_state.arn
}

output "dev_dynamodb_table_name" {
  value = aws_dynamodb_table.terraform_lock.name
}

output "prod_state_bucket_name" {
  value = aws_s3_bucket.terraform_state_prod.bucket
}

output "prod_state_bucket_arn" {
  value = aws_s3_bucket.terraform_state_prod.arn
}

output "prod_dynamodb_table_name" {
  value = aws_dynamodb_table.terraform_lock_prod.name
}
