data "aws_region" "current" {}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  region      = data.aws_region.current.id

  # Interface 엔드포인트 서비스 맵 (key → 태그명, value → 서비스 suffix)
  interface_services = {
    ecr_api        = "ecr.api"
    ecr_dkr        = "ecr.dkr"
    sts            = "sts"
    secretsmanager = "secretsmanager"
    sqs            = "sqs"
    sns            = "sns"
    logs           = "logs"
  }
}

# ── Interface Endpoint 전용 보안 그룹 ─────────────────────────────────
# EKS 워커노드 → VPC Endpoint 443 인바운드만 허용
resource "aws_security_group" "vpc_endpoint" {
  name        = "${local.name_prefix}-sg-vpce"
  description = "VPC Interface Endpoint — allow HTTPS from EKS worker nodes"
  vpc_id      = var.vpc_id

  ingress {
    description     = "HTTPS from EKS worker nodes"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [var.eks_sg_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name_prefix}-sg-vpce" }
}

# ── S3 Gateway Endpoint ───────────────────────────────────────────────
# 라우팅 테이블에 S3 prefix list 경로 자동 추가 (비용 없음)
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${local.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = var.private_route_table_ids

  tags = { Name = "${local.name_prefix}-vpce-s3" }
}

# ── Interface Endpoints ───────────────────────────────────────────────
resource "aws_vpc_endpoint" "interface" {
  for_each = local.interface_services

  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${local.region}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.eks_subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoint.id]
  private_dns_enabled = true

  tags = { Name = "${local.name_prefix}-vpce-${replace(each.value, ".", "-")}" }
}
