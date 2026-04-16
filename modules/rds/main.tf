locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ── DB Subnet Group ───────────────────────────────────────────────────
resource "aws_db_subnet_group" "main" {
  name       = "${local.name_prefix}-db-subnet-group"
  subnet_ids = var.data_subnet_ids

  tags = { Name = "${local.name_prefix}-db-subnet-group" }
}

# ── RDS Instance ──────────────────────────────────────────────────────
resource "aws_db_instance" "main" {
  identifier = "${local.name_prefix}-rds"

  engine         = "postgres"
  engine_version = "16"
  instance_class = var.instance_class

  allocated_storage = var.allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.rds_sg_id]
  publicly_accessible    = false

  multi_az            = false
  skip_final_snapshot = true
  deletion_protection = false

  lifecycle {
    ignore_changes = [engine_version]
  }

  tags = { Name = "${local.name_prefix}-rds" }
}
