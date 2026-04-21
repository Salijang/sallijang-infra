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

domain_name       = "sallijang.shop"
hosted_zone_id    = ""
certificate_arn   = "arn:aws:acm:ap-northeast-2:594486941613:certificate/508f9edb-f0a7-459a-9e6f-b11d95cd8f88"
node_port         = 30080
route53_zone_name = "sallijang.shop"
