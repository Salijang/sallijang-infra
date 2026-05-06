# ── Lambda Log Groups ─────────────────────────────────────────────────
# AWS는 Lambda 호출 시 /aws/lambda/<function-name> Log Group을 자동 생성한다.
# Terraform으로 retention을 관리하려면 이미 생성된 Log Group을 import해야 함.
#
# Import 절차 (각 함수마다 1회):
#   terraform import 'module.cloudwatch.aws_cloudwatch_log_group.lambda["pickup-dev-image-resize"]' /aws/lambda/pickup-dev-image-resize
resource "aws_cloudwatch_log_group" "lambda" {
  for_each = toset(var.lambda_function_names)

  name              = "/aws/lambda/${each.value}"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "/aws/lambda/${each.value}"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
