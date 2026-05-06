project_name = "pickup"
environment  = "prod"
aws_region   = "ap-northeast-2"

vpc_cidr           = "10.1.0.0/16"
availability_zones = ["ap-northeast-2a", "ap-northeast-2c"]

public_subnet_cidrs   = ["10.1.1.0/24", "10.1.2.0/24"]
eks_subnet_cidrs      = ["10.1.3.0/24", "10.1.4.0/24"]
realtime_subnet_cidrs = ["10.1.5.0/24", "10.1.6.0/24"]
data_subnet_cidrs     = ["10.1.7.0/24", "10.1.8.0/24"]

# EKS 1.30 / Amazon Linux 2 / ap-northeast-2
# 업데이트: aws ec2 describe-images --owners amazon --filters 'Name=name,Values=amazon-eks-node-1.30-v*' --query 'sort_by(Images,&CreationDate)[-1].ImageId' --output text
eks_node_ami_id = "ami-0cfd22eb40ec9c95a"

# 팀 공인 IP — 변경 시 curl -s https://checkip.amazonaws.com 으로 재확인 후 업데이트
eks_public_access_cidrs = ["180.68.46.170/32"]

domain_name       = "api.sallijang.shop"
hosted_zone_id    = "Z076739714CV5CNEDIAMO"
certificate_arn   = "arn:aws:acm:ap-northeast-2:594486941613:certificate/13988de3-1356-4c12-ad6d-72edfbfd11d4"
node_port         = 30080
route53_zone_name = "sallijang.shop"

grafana_admin_password = "CHANGE_ME_BEFORE_APPLY"

# Lambda 코드 S3 버킷 — 코드 업로드 후 설정
# lambda_code_s3_bucket    = "pickup-prod-lambda-code"
# image_resize_code_s3_key = "lambda/image-resize.zip"
# sns_notify_code_s3_key   = "lambda/sns-notify.zip"
lambda_code_s3_bucket = ""
