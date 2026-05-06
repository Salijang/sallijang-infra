terraform {
  backend "s3" {
    bucket         = "pickup-prod-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
    dynamodb_table = "pickup-prod-terraform-lock"
  }
}
