data "aws_ssm_parameter" "jwt_secret_key" {
  name            = "pickup-prod-jwt-secret-key"
  with_decryption = true
}

resource "kubernetes_secret" "user_service_secret" {
  metadata {
    name      = "user-service-secret"
    namespace = "default"
  }

  data = {
    secret-key = data.aws_ssm_parameter.jwt_secret_key.value
  }

  depends_on = [module.eks]
}
