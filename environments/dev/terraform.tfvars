project_name = "pickup"
environment  = "dev"
aws_region   = "ap-northeast-2"

vpc_cidr           = "10.0.0.0/16"
availability_zones = ["ap-northeast-2a", "ap-northeast-2c"]

public_subnet_cidrs   = ["10.0.1.0/24", "10.0.2.0/24"]
eks_subnet_cidrs      = ["10.0.3.0/24", "10.0.4.0/24"]
realtime_subnet_cidrs = ["10.0.5.0/24", "10.0.6.0/24"]
data_subnet_cidrs     = ["10.0.7.0/24", "10.0.8.0/24"]

# EKS 1.29 / Amazon Linux 2 / ap-northeast-2 최신 AMI ID
# 업데이트 필요 시: aws ec2 describe-images --owners amazon --filters 'Name=name,Values=amazon-eks-node-1.29-v*' --query 'sort_by(Images,&CreationDate)[-1].ImageId' --output text
eks_node_ami_id = "ami-0cfd22eb40ec9c95a"

# dev는 어디서든 접근 가능하도록 열어 둠 (학습/테스트 환경)
eks_public_access_cidrs = ["0.0.0.0/0"]

domain_name       = "sallijang.shop"
hosted_zone_id    = "Z076739714CV5CNEDIAMO"
certificate_arn   = "arn:aws:acm:ap-northeast-2:594486941613:certificate/13988de3-1356-4c12-ad6d-72edfbfd11d4"
node_port         = 30080
route53_zone_name = "sallijang.shop"

# Grafana 관리자 비밀번호 — git 커밋 전 반드시 변경하거나 TF_VAR_grafana_admin_password 환경 변수로 주입
# Lambda 코드 S3 버킷 — 코드 업로드 후 설정
# lambda_code_s3_bucket    = "pickup-dev-lambda-code"
# image_resize_code_s3_key = "lambda/image-resize.zip"
# sns_notify_code_s3_key   = "lambda/sns-notify.zip"
image_resize_code_s3_key = "lambda/image-resize.zip"
sns_notify_code_s3_key   = "lambda/sns-notify.zip"
