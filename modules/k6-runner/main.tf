data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  name_prefix        = "${var.project_name}-${var.environment}-k6-runner"
  results_bucket_arn = var.results_bucket_arn
}

resource "aws_security_group" "this" {
  count = var.enabled ? 1 : 0

  name        = "${local.name_prefix}-sg"
  description = "Security group for k6 runner. No inbound access; use SSM."
  vpc_id      = var.vpc_id

  egress {
    description = "Allow outbound HTTPS for package install, GitHub, AWS APIs, and target API."
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow outbound HTTP for package repositories that redirect from HTTP."
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow outbound DNS over UDP."
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow outbound DNS over TCP."
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name    = "${local.name_prefix}-sg"
    Purpose = "k6-runner"
  })
}

resource "aws_iam_role" "this" {
  count = var.enabled ? 1 : 0

  name = "${local.name_prefix}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(var.tags, {
    Name    = "${local.name_prefix}-role"
    Purpose = "k6-runner"
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  count = var.enabled ? 1 : 0

  role       = aws_iam_role.this[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "results_bucket" {
  count = var.enabled && local.results_bucket_arn != "" ? 1 : 0

  name = "${local.name_prefix}-results"
  role = aws_iam_role.this[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = local.results_bucket_arn
        Condition = {
          StringLike = {
            "s3:prefix" = [
              var.results_prefix,
              "${var.results_prefix}/*"
            ]
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "${local.results_bucket_arn}/${var.results_prefix}/*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "this" {
  count = var.enabled ? 1 : 0

  name = "${local.name_prefix}-profile"
  role = aws_iam_role.this[0].name

  tags = merge(var.tags, {
    Name    = "${local.name_prefix}-profile"
    Purpose = "k6-runner"
  })
}

resource "aws_instance" "this" {
  count = var.enabled ? 1 : 0

  ami                         = coalesce(var.ami_id, data.aws_ami.amazon_linux_2023.id)
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.this[0].id]
  associate_public_ip_address = var.associate_public_ip_address
  iam_instance_profile        = aws_iam_instance_profile.this[0].name

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  user_data = templatefile("${path.module}/templates/user_data.sh.tftpl", {
    aws_region     = var.aws_region
    k6_repo_url    = var.k6_repo_url
    checkout_ref   = var.k6_repo_ref
    k6_base_url    = var.k6_base_url
    results_bucket = var.results_bucket_name
    results_prefix = var.results_prefix
  })

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = merge(var.tags, {
    Name    = local.name_prefix
    Purpose = "k6-runner"
  })
}
