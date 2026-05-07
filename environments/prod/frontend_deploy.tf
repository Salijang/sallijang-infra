resource "null_resource" "frontend_deploy" {
  triggers = {
    bucket_name     = module.s3.frontend_bucket_name
    distribution_id = module.cloudfront.frontend_distribution_id
  }

  provisioner "local-exec" {
    working_dir = "${path.module}/../../../sallijang-frontend"
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      npm ci --prefer-offline && \
      npm run build && \
      aws s3 sync dist/ s3://${module.s3.frontend_bucket_name} \
        --delete \
        --cache-control "public, max-age=31536000, immutable" \
        --exclude "index.html" && \
      aws s3 cp dist/index.html s3://${module.s3.frontend_bucket_name}/index.html \
        --cache-control "public, max-age=300" && \
      MSYS_NO_PATHCONV=1 aws cloudfront create-invalidation \
        --distribution-id ${module.cloudfront.frontend_distribution_id} \
        --paths "/index.html"
    EOT
  }

  depends_on = [
    module.s3,
    module.cloudfront,
  ]
}
