module "k6_runner" {
  source = "../../modules/k6-runner"

  enabled      = var.k6_runner_enabled
  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region

  vpc_id    = module.vpc.vpc_id
  subnet_id = module.vpc.public_subnet_ids[0]

  instance_type               = var.k6_runner_instance_type
  associate_public_ip_address = true

  k6_repo_url = var.k6_runner_repo_url
  k6_repo_ref = var.k6_runner_repo_ref
  k6_base_url = var.k6_runner_base_url

  results_bucket_name = module.s3.log_bucket_name
  results_bucket_arn  = module.s3.log_bucket_arn
  results_prefix      = var.k6_runner_results_prefix

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
