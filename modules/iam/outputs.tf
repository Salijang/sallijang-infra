output "order_sa_role_arn" {
  description = "sallijang-order-sa IAM Role ARN"
  value       = aws_iam_role.order.arn
}

output "order_sa_role_name" {
  description = "sallijang-order-sa IAM Role name"
  value       = aws_iam_role.order.name
}

output "product_sa_role_arn" {
  description = "sallijang-product-sa IAM Role ARN"
  value       = aws_iam_role.product.arn
}

output "product_sa_role_name" {
  description = "sallijang-product-sa IAM Role name"
  value       = aws_iam_role.product.name
}

output "user_sa_role_arn" {
  description = "sallijang-user-sa IAM Role ARN"
  value       = aws_iam_role.user.arn
}

output "user_sa_role_name" {
  description = "sallijang-user-sa IAM Role name"
  value       = aws_iam_role.user.name
}

output "frontend_sa_role_arn" {
  description = "sallijang-frontend-sa IAM Role ARN"
  value       = aws_iam_role.frontend.arn
}

output "frontend_sa_role_name" {
  description = "sallijang-frontend-sa IAM Role name"
  value       = aws_iam_role.frontend.name
}
