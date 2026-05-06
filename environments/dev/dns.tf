# dns.tf
# api.sallijang.shop → ALB
#
# sallijang.shop (apex) 는 alb 모듈이 생성.
# Ingress host(api.sallijang.shop)가 다른 서브도메인이므로 별도 레코드 필요.

data "aws_route53_zone" "main" {
  zone_id = var.hosted_zone_id
}

resource "aws_route53_record" "api" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "api.${var.domain_name}"
  type    = "A"

  alias {
    name                   = module.alb.alb_dns_name
    zone_id                = module.alb.alb_zone_id
    evaluate_target_health = true
  }
}
