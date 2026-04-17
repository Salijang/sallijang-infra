locals {
  name_prefix  = "${var.project_name}-${var.environment}"
  cluster_name = "${local.name_prefix}-eks-cluster"
}

# ── IAM: 클러스터 Role ────────────────────────────────────────────────
resource "aws_iam_role" "cluster" {
  name = "${local.name_prefix}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Name = "${local.name_prefix}-eks-cluster-role" }
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# ── IAM: 워커 노드 Role ───────────────────────────────────────────────
resource "aws_iam_role" "node" {
  name = "${local.name_prefix}-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Name = "${local.name_prefix}-eks-node-role" }
}

resource "aws_iam_role_policy_attachment" "node_worker" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_cni" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "node_ecr" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "node" {
  name = "${local.name_prefix}-eks-node-profile"
  role = aws_iam_role.node.name

  tags = { Name = "${local.name_prefix}-eks-node-profile" }
}

# ── 보안 그룹: 컨트롤 플레인 추가 SG ──────────────────────────────────
resource "aws_security_group" "control_plane" {
  name        = "${local.name_prefix}-sg-eks-cp"
  description = "EKS Control Plane additional SG — 워커 노드와의 통신용"
  vpc_id      = var.vpc_id

  tags = { Name = "${local.name_prefix}-sg-eks-cp" }
}

# ── 보안 그룹: 워커 노드 SG ───────────────────────────────────────────
resource "aws_security_group" "node" {
  name        = "${local.name_prefix}-sg-eks-node"
  description = "EKS Self-managed worker node SG"
  vpc_id      = var.vpc_id

  # 노드 간 전체 통신 허용 (CoreDNS, kube-proxy 등)
  ingress {
    description = "Node to node all traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name_prefix}-sg-eks-node" }
}

# 컨트롤 플레인 → 워커 노드: kubelet (10250)
resource "aws_security_group_rule" "cp_to_node_kubelet" {
  type                     = "ingress"
  from_port                = 10250
  to_port                  = 10250
  protocol                 = "tcp"
  description              = "Control plane to node: kubelet"
  security_group_id        = aws_security_group.node.id
  source_security_group_id = aws_security_group.control_plane.id
}

# 컨트롤 플레인 → 워커 노드: HTTPS (443)
resource "aws_security_group_rule" "cp_to_node_https" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  description              = "Control plane to node: HTTPS"
  security_group_id        = aws_security_group.node.id
  source_security_group_id = aws_security_group.control_plane.id
}

# 컨트롤 플레인 → 워커 노드: DNS TCP (53)
resource "aws_security_group_rule" "cp_to_node_dns_tcp" {
  type                     = "ingress"
  from_port                = 53
  to_port                  = 53
  protocol                 = "tcp"
  description              = "Control plane to node: DNS TCP"
  security_group_id        = aws_security_group.node.id
  source_security_group_id = aws_security_group.control_plane.id
}

# 컨트롤 플레인 → 워커 노드: DNS UDP (53)
resource "aws_security_group_rule" "cp_to_node_dns_udp" {
  type                     = "ingress"
  from_port                = 53
  to_port                  = 53
  protocol                 = "udp"
  description              = "Control plane to node: DNS UDP"
  security_group_id        = aws_security_group.node.id
  source_security_group_id = aws_security_group.control_plane.id
}

# 워커 노드 → 컨트롤 플레인: API 서버 (443)
resource "aws_security_group_rule" "node_to_cp_https" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  description              = "Node to control plane: HTTPS (API server)"
  security_group_id        = aws_security_group.control_plane.id
  source_security_group_id = aws_security_group.node.id
}

# ── EKS 클러스터 ──────────────────────────────────────────────────────
resource "aws_eks_cluster" "main" {
  name     = local.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = var.cluster_version

  vpc_config {
    subnet_ids              = var.eks_subnet_ids
    security_group_ids      = [aws_security_group.control_plane.id]
    endpoint_public_access  = true
    endpoint_private_access = true
    public_access_cidrs     = var.public_access_cidrs
  }

  access_config {
    # API + ConfigMap 병행 — kubectl, eksctl 등 도구 호환성 유지
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy,
  ]

  tags = { Name = local.cluster_name }
}

# ── OIDC Provider (IRSA용) ────────────────────────────────────────────
data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "main" {
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]

  tags = { Name = "${local.name_prefix}-eks-oidc" }
}

# ── EKS Access Entry: 워커 노드 Role 자동 등록 (aws-auth 대체) ─────────
# EC2_LINUX 타입은 별도 정책 연결 없이 노드 join 권한 자동 부여
resource "aws_eks_access_entry" "node" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = aws_iam_role.node.arn
  type          = "EC2_LINUX"

  depends_on = [aws_eks_cluster.main]
}

# ── EKS 최적화 AMI (Amazon Linux 2) ──────────────────────────────────
# SSM Parameter Store에서 클러스터 버전별 최신 AMI ID 자동 조회
data "aws_ssm_parameter" "eks_ami" {
  name = "/aws/service/eks/optimized-ami/${var.cluster_version}/amazon-linux-2/recommended/image_id"
}

# ── Launch Template ───────────────────────────────────────────────────
resource "aws_launch_template" "node" {
  name_prefix = "${local.name_prefix}-eks-node-"
  description = "EKS Self-managed worker node launch template"

  image_id      = data.aws_ssm_parameter.eks_ami.value
  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.node.name
  }

  vpc_security_group_ids = [
    aws_security_group.node.id,
    var.eks_sg_id, # VPC 모듈 SG — RDS(5432)/Redis(6379) 인바운드 소스로 이미 등록됨
  ]

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = var.node_volume_size
      volume_type           = "gp3"
      delete_on_termination = true
      encrypted             = true
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"  # IMDSv2 강제 (보안)
    http_put_response_hop_limit = 2           # 컨테이너 내부에서 IMDS 접근 가능하도록 hop=2
  }

  user_data = base64encode(templatefile("${path.module}/templates/userdata.sh.tpl", {
    cluster_name     = aws_eks_cluster.main.name
    cluster_endpoint = aws_eks_cluster.main.endpoint
    cluster_ca       = aws_eks_cluster.main.certificate_authority[0].data
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${local.name_prefix}-eks-node"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ── Auto Scaling Group ────────────────────────────────────────────────
resource "aws_autoscaling_group" "node" {
  name = "${local.name_prefix}-eks-node-asg"

  min_size         = var.node_min_size
  desired_capacity = var.node_desired_size
  max_size         = var.node_max_size

  # 2개 AZ 서브넷 지정 — ASG가 AZ별로 균등 분배 (desired=2 → AZ당 1대, max=4 → AZ당 2대)
  vpc_zone_identifier = var.eks_subnet_ids

  launch_template {
    id      = aws_launch_template.node.id
    version = "$Latest"
  }

  # EKS 클러스터 디스커버리 태그 (Cluster Autoscaler 필수)
  tag {
    key                 = "kubernetes.io/cluster/${aws_eks_cluster.main.name}"
    value               = "owned"
    propagate_at_launch = true
  }

  tag {
    key                 = "Name"
    value               = "${local.name_prefix}-eks-node"
    propagate_at_launch = true
  }

  # Cluster Autoscaler가 desired_capacity를 조정하므로 Terraform이 덮어쓰지 않도록
  lifecycle {
    ignore_changes = [desired_capacity]
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_worker,
    aws_iam_role_policy_attachment.node_cni,
    aws_iam_role_policy_attachment.node_ecr,
    aws_eks_access_entry.node,
  ]
}
