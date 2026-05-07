resource "aws_ssm_parameter" "frontend_distribution_id" {
  name  = "/pickup/prod/cloudfront/frontend-distribution-id"
  type  = "String"
  value = module.cloudfront.frontend_distribution_id

  tags = { Name = "pickup-prod-frontend-distribution-id" }
}

resource "aws_ssm_parameter" "frontend_bucket_name" {
  name  = "/pickup/prod/s3/frontend-bucket-name"
  type  = "String"
  value = module.s3.frontend_bucket_name

  tags = { Name = "pickup-prod-frontend-bucket-name" }
}

resource "aws_ssm_parameter" "lambda_bucket_name" {
  name  = "/pickup/prod/s3/lambda-bucket-name"
  type  = "String"
  value = module.s3.lambda_bucket_name

  tags = { Name = "pickup-prod-lambda-bucket-name" }
}
