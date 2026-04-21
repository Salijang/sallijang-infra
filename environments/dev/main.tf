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

  kubernetes_namespace = var.kubernetes_namespace
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
}
