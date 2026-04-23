locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ── VPC ──────────────────────────────────────────────────────────────
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${local.name_prefix}-vpc" }
}

# ── Subnets ───────────────────────────────────────────────────────────
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name                     = "${local.name_prefix}-subnet-public-${count.index == 0 ? "a" : "c"}"
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_subnet" "eks" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.eks_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name                              = "${local.name_prefix}-subnet-eks-${count.index == 0 ? "a" : "c"}"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

resource "aws_subnet" "realtime" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.realtime_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "${local.name_prefix}-subnet-realtime-${count.index == 0 ? "a" : "c"}"
  }
}

resource "aws_subnet" "data" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.data_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "${local.name_prefix}-subnet-data-${count.index == 0 ? "a" : "c"}"
  }
}

# ── Internet Gateway ──────────────────────────────────────────────────
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = { Name = "${local.name_prefix}-igw" }
}

# ── NAT Gateway (AZ별 1개) ────────────────────────────────────────────
resource "aws_eip" "nat" {
  count  = length(var.availability_zones)
  domain = "vpc"

  tags = { Name = "${local.name_prefix}-eip-nat-${count.index == 0 ? "a" : "c"}" }
}

resource "aws_nat_gateway" "main" {
  count         = length(var.availability_zones)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags       = { Name = "${local.name_prefix}-nat-${count.index == 0 ? "a" : "c"}" }
  depends_on = [aws_internet_gateway.main]
}

# ── Route Tables ──────────────────────────────────────────────────────
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "${local.name_prefix}-rt-public" }
}

resource "aws_route_table" "private" {
  count  = 2
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = { Name = "${local.name_prefix}-rt-private-${count.index == 0 ? "a" : "c"}" }
}

# ── Route Table Associations ──────────────────────────────────────────
resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "eks" {
  count          = 2
  subnet_id      = aws_subnet.eks[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

resource "aws_route_table_association" "realtime" {
  count          = 2
  subnet_id      = aws_subnet.realtime[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

resource "aws_route_table_association" "data" {
  count          = 2
  subnet_id      = aws_subnet.data[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# 1. ALB 보안 그룹 (껍데기)
resource "aws_security_group" "alb" {
  name   = "${local.name_prefix}-sg-alb"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name_prefix}-sg-alb" }
}

# 2. EKS 보안 그룹
resource "aws_security_group" "eks" {
  name   = "${local.name_prefix}-sg-eks"
  vpc_id = aws_vpc.main.id

  tags = { Name = "${local.name_prefix}-sg-eks" }
}

resource "aws_security_group_rule" "eks_self_all" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  description       = "Node to node communication"
  security_group_id = aws_security_group.eks.id
  self              = true
}

resource "aws_security_group_rule" "eks_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.eks.id
  cidr_blocks       = ["0.0.0.0/0"]
}

# 3. 순환 참조를 끊어주는 연결 규칙 (핵심!)
resource "aws_security_group_rule" "alb_to_eks_egress" {
  type                     = "egress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.alb.id
  source_security_group_id = aws_security_group.eks.id # 여기서 서로 연결
}

resource "aws_security_group_rule" "eks_from_alb_ingress" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks.id
  source_security_group_id = aws_security_group.alb.id # 여기서 서로 연결
}



# ── RDS 보안 그룹 (추가) ───────────────────────────────────────────
resource "aws_security_group" "rds" {
  name        = "${local.name_prefix}-sg-rds"
  vpc_id      = aws_vpc.main.id
  description = "RDS Security Group"

  tags = { Name = "${local.name_prefix}-sg-rds" }
}

# RDS용 인바운드 규칙 (EKS에서 오는 5432 포트 허용)
resource "aws_security_group_rule" "rds_from_eks" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds.id
  source_security_group_id = aws_security_group.eks.id
}

# ── Redis 보안 그룹 (추가) ─────────────────────────────────────────
resource "aws_security_group" "redis" {
  name        = "${local.name_prefix}-sg-redis"
  vpc_id      = aws_vpc.main.id
  description = "Redis Security Group"

  tags = { Name = "${local.name_prefix}-sg-redis" }
}

# Redis용 인바운드 규칙 (EKS에서 오는 6379 포트 허용)
resource "aws_security_group_rule" "redis_from_eks" {
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  security_group_id        = aws_security_group.redis.id
  source_security_group_id = aws_security_group.eks.id
}