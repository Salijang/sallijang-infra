# ── Unified CloudWatch Dashboard ──────────────────────────────────────
# RDS / Lambda / ALB / CloudFront 핵심 지표를 한 화면에. 읽기 전용 — 어떤 기존 리소스도 영향 없음.

locals {
  dashboard_enabled = var.enable_dashboard

  lambda_widgets = [
    for fn in var.lambda_function_names : {
      type   = "metric"
      width  = 12
      height = 6
      properties = {
        title  = "Lambda — ${fn}"
        region = var.aws_region
        view   = "timeSeries"
        stat   = "Sum"
        period = 300
        metrics = [
          ["AWS/Lambda", "Invocations", "FunctionName", fn],
          [".", "Errors", ".", "."],
          [".", "Throttles", ".", "."],
          [".", "Duration", ".", ".", { stat = "p95" }],
        ]
      }
    }
  ]

  rds_widget = var.rds_instance_id == "" ? [] : [{
    type   = "metric"
    width  = 24
    height = 6
    properties = {
      title  = "RDS — ${var.rds_instance_id}"
      region = var.aws_region
      view   = "timeSeries"
      stat   = "Average"
      period = 300
      metrics = [
        ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", var.rds_instance_id],
        [".", "FreeableMemory", ".", "."],
        [".", "DatabaseConnections", ".", "."],
        [".", "ReadIOPS", ".", "."],
        [".", "WriteIOPS", ".", "."],
      ]
    }
  }]

  alb_widget = var.alb_arn_suffix == "" ? [] : [{
    type   = "metric"
    width  = 24
    height = 6
    properties = {
      title  = "ALB"
      region = var.aws_region
      view   = "timeSeries"
      period = 300
      metrics = [
        ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.alb_arn_suffix, { stat = "Sum" }],
        [".", "HTTPCode_ELB_5XX_Count", ".", ".", { stat = "Sum" }],
        [".", "HTTPCode_Target_5XX_Count", ".", ".", { stat = "Sum" }],
        [".", "TargetResponseTime", ".", ".", { stat = "p95" }],
      ]
    }
  }]

  cloudfront_widgets = [
    for id in var.cloudfront_distribution_ids : {
      type   = "metric"
      width  = 12
      height = 6
      properties = {
        title  = "CloudFront — ${id}"
        region = "us-east-1" # CloudFront 메트릭은 항상 us-east-1
        view   = "timeSeries"
        period = 300
        metrics = [
          ["AWS/CloudFront", "Requests", "DistributionId", id, "Region", "Global", { stat = "Sum" }],
          [".", "5xxErrorRate", ".", ".", ".", ".", { stat = "Average" }],
          [".", "4xxErrorRate", ".", ".", ".", ".", { stat = "Average" }],
          [".", "BytesDownloaded", ".", ".", ".", ".", { stat = "Sum" }],
        ]
      }
    }
  ]

  dashboard_body = {
    widgets = concat(
      local.rds_widget,
      local.lambda_widgets,
      local.alb_widget,
      local.cloudfront_widgets,
    )
  }
}

resource "aws_cloudwatch_dashboard" "main" {
  count = local.dashboard_enabled ? 1 : 0

  dashboard_name = "${local.name_prefix}-overview"
  dashboard_body = jsonencode(local.dashboard_body)
}
