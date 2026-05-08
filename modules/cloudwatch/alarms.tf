# ── Metric Alarms ─────────────────────────────────────────────────────
# 모든 알람은 신규 리소스만 추가 (기존 인프라 무수정).
# enable_alarms = false 인 동안은 어떤 알람도 생성되지 않음.

locals {
  alarms_enabled = var.enable_alarms
  rds_alarms     = local.alarms_enabled && var.rds_instance_id != ""
  alb_alarm_targets = local.alarms_enabled && var.create_alb_alarms ? {
    main = var.alb_arn_suffix
  } : {}
  alb_target_group_alarm_targets = local.alarms_enabled && var.enable_extended_metrics && var.create_alb_alarms && var.alb_target_group_arn_suffix != "" ? {
    main = {
      load_balancer = var.alb_arn_suffix
      target_group  = var.alb_target_group_arn_suffix
    }
  } : {}
  cf_distros    = local.alarms_enabled ? var.cloudfront_distribution_ids_by_name : {}
  lambda_alarms = toset(local.alarms_enabled ? var.lambda_function_names : [])
  rds_replica_alarms = local.alarms_enabled && var.enable_extended_metrics ? {
    for id in var.rds_replica_instance_ids : id => id
  } : {}
  alarm_actions = local.alarms_enabled && var.sns_topic_arn != "" ? [var.sns_topic_arn] : []
  ok_actions    = local.alarm_actions
  default_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# ── RDS ───────────────────────────────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  count = local.rds_alarms ? 1 : 0

  alarm_name          = "${local.name_prefix}-rds-cpu-high"
  alarm_description   = "RDS CPU > 80% over 10 minutes"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  treat_missing_data  = "notBreaching"

  dimensions = { DBInstanceIdentifier = var.rds_instance_id }

  alarm_actions = local.alarm_actions
  ok_actions    = local.ok_actions

  tags = merge(local.default_tags, { Name = "${local.name_prefix}-rds-cpu-high" })
}

resource "aws_cloudwatch_metric_alarm" "rds_freeable_memory" {
  count = local.rds_alarms ? 1 : 0

  alarm_name          = "${local.name_prefix}-rds-freeable-memory-low"
  alarm_description   = "RDS FreeableMemory < 100MB"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "FreeableMemory"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 100 * 1024 * 1024 # bytes
  treat_missing_data  = "notBreaching"

  dimensions = { DBInstanceIdentifier = var.rds_instance_id }

  alarm_actions = local.alarm_actions
  ok_actions    = local.ok_actions

  tags = merge(local.default_tags, { Name = "${local.name_prefix}-rds-freeable-memory-low" })
}

resource "aws_cloudwatch_metric_alarm" "rds_connections" {
  count = local.rds_alarms ? 1 : 0

  alarm_name          = "${local.name_prefix}-rds-connections-high"
  alarm_description   = "RDS DatabaseConnections > 80 (db.t3.small 기준 약 80% 임계)"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  treat_missing_data  = "notBreaching"

  dimensions = { DBInstanceIdentifier = var.rds_instance_id }

  alarm_actions = local.alarm_actions
  ok_actions    = local.ok_actions

  tags = merge(local.default_tags, { Name = "${local.name_prefix}-rds-connections-high" })
}

resource "aws_cloudwatch_metric_alarm" "rds_replication_lag" {
  for_each = local.rds_replica_alarms

  alarm_name          = "${each.value}-replication-lag-high"
  alarm_description   = "RDS Read Replica ${each.value} ReplicationLag > 60s"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ReplicationLag"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 60
  treat_missing_data  = "notBreaching"

  dimensions = { DBInstanceIdentifier = each.value }

  alarm_actions = local.alarm_actions
  ok_actions    = local.ok_actions

  tags = merge(local.default_tags, { Name = "${each.value}-replication-lag-high" })
}

# ── Lambda (함수별 알람) ──────────────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  for_each = local.lambda_alarms

  alarm_name          = "${each.value}-errors-high"
  alarm_description   = "Lambda ${each.value} Errors > 5 / 5min"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  treat_missing_data  = "notBreaching"

  dimensions = { FunctionName = each.value }

  alarm_actions = local.alarm_actions
  ok_actions    = local.ok_actions

  tags = merge(local.default_tags, { Name = "${each.value}-errors-high" })
}

resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  for_each = local.lambda_alarms

  alarm_name          = "${each.value}-throttles"
  alarm_description   = "Lambda ${each.value} Throttles > 0"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = { FunctionName = each.value }

  alarm_actions = local.alarm_actions
  ok_actions    = local.ok_actions

  tags = merge(local.default_tags, { Name = "${each.value}-throttles" })
}

resource "aws_cloudwatch_metric_alarm" "lambda_duration_p95" {
  for_each = local.lambda_alarms

  alarm_name          = "${each.value}-duration-p95-high"
  alarm_description   = "Lambda ${each.value} Duration p95 > 80% of timeout"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 300
  extended_statistic  = "p95"
  threshold           = var.lambda_timeout_seconds * 1000 * 0.8 # ms 단위
  treat_missing_data  = "notBreaching"

  dimensions = { FunctionName = each.value }

  alarm_actions = local.alarm_actions
  ok_actions    = local.ok_actions

  tags = merge(local.default_tags, { Name = "${each.value}-duration-p95-high" })
}

# ── ALB ───────────────────────────────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  for_each = local.alb_alarm_targets

  alarm_name          = "${local.name_prefix}-alb-5xx-high"
  alarm_description   = "ALB HTTPCode_ELB_5XX_Count > 10 / 5min"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  treat_missing_data  = "notBreaching"

  dimensions = { LoadBalancer = each.value }

  alarm_actions = local.alarm_actions
  ok_actions    = local.ok_actions

  tags = merge(local.default_tags, { Name = "${local.name_prefix}-alb-5xx-high" })
}

resource "aws_cloudwatch_metric_alarm" "alb_target_response_time" {
  for_each = local.alb_alarm_targets

  alarm_name          = "${local.name_prefix}-alb-target-response-time-p95-high"
  alarm_description   = "ALB TargetResponseTime p95 > 1s"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  extended_statistic  = "p95"
  threshold           = 1 # seconds
  treat_missing_data  = "notBreaching"

  dimensions = { LoadBalancer = each.value }

  alarm_actions = local.alarm_actions
  ok_actions    = local.ok_actions

  tags = merge(local.default_tags, { Name = "${local.name_prefix}-alb-target-response-time-p95-high" })
}

resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_host" {
  for_each = local.alb_target_group_alarm_targets

  alarm_name          = "${local.name_prefix}-alb-unhealthy-host"
  alarm_description   = "ALB UnHealthyHostCount > 0"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Average"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = each.value.load_balancer
    TargetGroup  = each.value.target_group
  }

  alarm_actions = local.alarm_actions
  ok_actions    = local.ok_actions

  tags = merge(local.default_tags, { Name = "${local.name_prefix}-alb-unhealthy-host" })
}

# ── CloudFront ────────────────────────────────────────────────────────
# CloudFront 메트릭은 us-east-1 기준이지만 알람은 어느 리전에서든 생성 가능.
resource "aws_cloudwatch_metric_alarm" "cloudfront_5xx" {
  for_each = local.cf_distros

  alarm_name          = "${local.name_prefix}-cf-${substr(each.value, 0, 8)}-5xx-high"
  alarm_description   = "CloudFront ${each.value} 5xxErrorRate > 1%"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "5xxErrorRate"
  namespace           = "AWS/CloudFront"
  period              = 300
  statistic           = "Average"
  threshold           = 1
  treat_missing_data  = "notBreaching"

  dimensions = {
    DistributionId = each.value
    Region         = "Global"
  }

  alarm_actions = local.alarm_actions
  ok_actions    = local.ok_actions

  tags = merge(local.default_tags, { Name = "${local.name_prefix}-cf-${substr(each.value, 0, 8)}-5xx-high" })
}
