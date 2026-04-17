locals {
  name_prefix     = "${var.project_name}-${var.environment}"
  enable_multi_az = var.num_cache_clusters > 1
}

# ── Subnet Group ──────────────────────────────────────────────────────
resource "aws_elasticache_subnet_group" "main" {
  name       = "${local.name_prefix}-redis-subnet-group"
  subnet_ids = var.realtime_subnet_ids

  tags = {
    Name        = "${local.name_prefix}-redis-subnet-group"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# ── Replication Group (Redis) ─────────────────────────────────────────
resource "aws_elasticache_replication_group" "main" {
  replication_group_id = "${local.name_prefix}-redis"
  description          = "Redis replication group for ${local.name_prefix}"

  engine               = "redis"
  engine_version       = var.redis_version
  node_type            = var.node_type
  num_cache_clusters   = var.num_cache_clusters
  port                 = 6379

  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = [var.redis_sg_id]

  # Multi-AZ + 자동 장애 조치 (클러스터 2개 이상일 때만 활성화)
  automatic_failover_enabled = local.enable_multi_az
  multi_az_enabled           = local.enable_multi_az

  # 보안
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true

  # 유지보수
  apply_immediately          = false
  auto_minor_version_upgrade = true
  maintenance_window         = "sun:17:00-sun:18:00"
  snapshot_retention_limit   = 7
  snapshot_window            = "16:00-17:00"

  tags = {
    Name        = "${local.name_prefix}-redis"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
