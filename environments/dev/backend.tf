terraform {
  backend "s3" {
    bucket         = "pickup-dev-terraform-state"
    key            = "dev/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "pickup-dev-terraform-lock"
    encrypt        = true
  }
}
