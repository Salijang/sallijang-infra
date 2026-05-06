module "vpc" {
  source = "../../modules/vpc"

  project_name = var.project_name
  environment  = var.environment

  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones

  public_subnet_cidrs   = var.public_subnet_cidrs
  eks_subnet_cidrs      = var.eks_subnet_cidrs
  realtime_subnet_cidrs = var.realtime_subnet_cidrs
  data_subnet_cidrs     = var.data_subnet_cidrs
}
module "elasticache" {
  source = "../../modules/elasticache"

  project_name = var.project_name
  environment  = var.environment

  realtime_subnet_ids = module.vpc.realtime_subnet_ids
  redis_sg_id         = module.vpc.redis_sg_id

  node_type          = "cache.t3.micro"
  redis_version      = "7.0"
  num_cache_clusters = 1
}

module "rds" {
  source = "../../modules/rds"

  project_name = var.project_name
  environment  = var.environment

  vpc_id          = module.vpc.vpc_id
  data_subnet_ids = module.vpc.data_subnet_ids
  eks_subnet_ids  = module.vpc.eks_subnet_ids
  rds_sg_id       = module.vpc.rds_sg_id
  eks_sg_id       = module.vpc.eks_sg_id

  instance_class    = "db.t3.small"
allocated_storage = 20

  db_name     = "pickupdb"
  db_username = "adminuser"
}

module "eks" {
  source = "../../modules/eks"

  project_name = var.project_name
  environment  = var.environment

  vpc_id         = module.vpc.vpc_id
  eks_subnet_ids = module.vpc.eks_subnet_ids
  eks_sg_id      = module.vpc.eks_sg_id

  node_ami_id       = var.eks_node_ami_id
  target_group_arns = [module.alb.target_group_arn]
}

module "s3" {
  source = "../../modules/s3"

  project_name  = var.project_name
  environment   = var.environment
  force_destroy = true
}

module "sqs" {
  source = "../../modules/sqs"

  project_name = var.project_name
  environment  = var.environment
}

# ── Saga 패턴용 재고 차감 큐 ─────────────────────────────────────────
resource "aws_sqs_queue" "stock_deduct_dlq" {
  name                      = "${var.project_name}-${var.environment}-stock-deduct-dlq"
  message_retention_seconds = 1209600
  sqs_managed_sse_enabled   = true
  tags = { Name = "${var.project_name}-${var.environment}-stock-deduct-dlq" }
}

resource "aws_sqs_queue" "stock_deduct" {
  name                       = "${var.project_name}-${var.environment}-stock-deduct"
  visibility_timeout_seconds = 30
  message_retention_seconds  = 86400
  sqs_managed_sse_enabled    = true
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.stock_deduct_dlq.arn
    maxReceiveCount     = 3
  })
  tags = { Name = "${var.project_name}-${var.environment}-stock-deduct" }
}

resource "aws_sqs_queue_redrive_allow_policy" "stock_deduct_dlq" {
  queue_url = aws_sqs_queue.stock_deduct_dlq.id
  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.stock_deduct.arn]
  })
}

# ── Saga 패턴용 재고 차감 결과 큐 ────────────────────────────────────
resource "aws_sqs_queue" "stock_result_dlq" {
  name                      = "${var.project_name}-${var.environment}-stock-result-dlq"
  message_retention_seconds = 1209600
  sqs_managed_sse_enabled   = true
  tags = { Name = "${var.project_name}-${var.environment}-stock-result-dlq" }
}

resource "aws_sqs_queue" "stock_result" {
  name                       = "${var.project_name}-${var.environment}-stock-result"
  visibility_timeout_seconds = 30
  message_retention_seconds  = 86400
  sqs_managed_sse_enabled    = true
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.stock_result_dlq.arn
    maxReceiveCount     = 3
  })
  tags = { Name = "${var.project_name}-${var.environment}-stock-result" }
}

resource "aws_sqs_queue_redrive_allow_policy" "stock_result_dlq" {
  queue_url = aws_sqs_queue.stock_result_dlq.id
  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.stock_result.arn]
  })
}

module "sns" {
  source = "../../modules/sns"

  project_name     = var.project_name
  environment      = var.environment
  sqs_endpoint_arn = module.sqs.queue_arn
}

module "iam" {
  source = "../../modules/iam"

  project_name = var.project_name
  environment  = var.environment

  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_issuer_url   = module.eks.oidc_issuer_url

  sqs_queue_arn    = module.sqs.queue_arn
  sqs_dlq_arn      = module.sqs.dlq_arn
  sns_topic_arn    = module.sns.topic_arn
  image_bucket_arn = module.s3.image_bucket_arn

  stock_deduct_queue_arn = aws_sqs_queue.stock_deduct.arn
  stock_deduct_dlq_arn   = aws_sqs_queue.stock_deduct_dlq.arn
  stock_result_queue_arn = aws_sqs_queue.stock_result.arn
  stock_result_dlq_arn   = aws_sqs_queue.stock_result_dlq.arn

  kubernetes_namespace = var.kubernetes_namespace
  db_username          = "adminuser"
}

module "cloudfront" {
  source = "../../modules/cloudfront"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  project_name = var.project_name
  environment  = var.environment

  image_bucket_name                 = module.s3.image_bucket_name
  image_bucket_arn                  = module.s3.image_bucket_arn
  image_bucket_regional_domain_name = module.s3.image_bucket_regional_domain_name

  frontend_bucket_name                 = module.s3.frontend_bucket_name
  frontend_bucket_arn                  = module.s3.frontend_bucket_arn
  frontend_bucket_regional_domain_name = module.s3.frontend_bucket_regional_domain_name

  log_bucket_domain_name = module.s3.log_bucket_domain_name

  hosted_zone_id    = var.hosted_zone_id
  domain_name       = var.domain_name
  route53_zone_name = var.route53_zone_name
}

module "karpenter" {
  source = "../../modules/karpenter"

  project_name = var.project_name
  environment  = var.environment

  cluster_name      = module.eks.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_issuer_url   = module.eks.oidc_issuer_url

  eks_subnet_ids = module.vpc.eks_subnet_ids
  node_sg_id     = module.eks.node_sg_id
}

module "vpc_endpoints" {
  source = "../../modules/vpc-endpoints"

  project_name = var.project_name
  environment  = var.environment

  vpc_id                  = module.vpc.vpc_id
  eks_subnet_ids          = module.vpc.eks_subnet_ids
  private_route_table_ids = module.vpc.private_route_table_ids
  eks_sg_id               = module.vpc.eks_sg_id
}

module "lambda" {
  source = "../../modules/lambda"

  project_name = var.project_name
  environment  = var.environment

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.data_subnet_ids

  image_bucket_name = module.s3.image_bucket_name
  image_bucket_arn  = module.s3.image_bucket_arn
  sns_topic_arn     = module.sns.topic_arn

  deploy_lambda            = true
  code_s3_bucket           = module.s3.lambda_bucket_name
  image_resize_code_s3_key = var.image_resize_code_s3_key
  sns_notify_code_s3_key   = var.sns_notify_code_s3_key
}

module "alb" {
  source = "../../modules/alb"

  project_name = var.project_name
  environment  = var.environment

  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  alb_sg_id         = module.vpc.alb_sg_id

  domain_name       = var.domain_name
  hosted_zone_id    = var.hosted_zone_id
  certificate_arn   = var.certificate_arn
  node_port         = var.node_port
  route53_zone_name = var.route53_zone_name

  log_bucket_name = module.s3.log_bucket_name
}
