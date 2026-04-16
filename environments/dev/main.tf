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

  # [중요] VPC 모듈이 만든 결과물(Output)을 RDS의 재료(Variable)로 꽂아줍니다.
  data_subnet_ids = module.vpc.data_subnet_ids
  rds_sg_id       = module.vpc.rds_sg_id

  # 멘토님 가이드: 최소 사양 (t3.small)
  instance_class    = "db.t3.small"
  allocated_storage = 20

  # DB 접속 정보 (가급적 variables.tf에 정의해서 쓰세요)
  db_name     = "pickupdb"
  db_username = "adminuser"
  db_password = "yourpassword123!" # 실제로는 보안상 주의!
}
