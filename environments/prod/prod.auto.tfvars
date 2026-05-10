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
eks_node_ami_id = "ami-0cfd22eb40ec9c95a"

# Team-approved public IPs for EKS API access.
eks_public_access_cidrs = ["180.68.46.170/32", "58.122.29.203/32", "49.168.185.250/32"]

domain_name       = "api.sallijang.shop"
hosted_zone_id    = "Z076739714CV5CNEDIAMO"
certificate_arn   = "arn:aws:acm:ap-northeast-2:594486941613:certificate/13988de3-1356-4c12-ad6d-72edfbfd11d4"
node_port         = 30080
route53_zone_name = "sallijang.shop"

alertmanager_slack_channel = "#resource-alert"
slack_workspace_id         = "T0A28LL1RUL"
slack_channel_id           = "C0B2FUW2VD0"
