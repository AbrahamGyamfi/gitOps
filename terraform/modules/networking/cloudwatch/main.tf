resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${var.project_name}/${var.service_name}"
  retention_in_days = var.retention_days

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.project_name}-${var.service_name}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "60"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "CPU utilization is too high"

  dimensions = {
    ClusterName = var.cluster_name
    ServiceName = var.service_name
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "memory_high" {
  alarm_name          = "${var.project_name}-${var.service_name}-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = "60"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "Memory utilization is too high"

  dimensions = {
    ClusterName = var.cluster_name
    ServiceName = var.service_name
  }

  tags = var.tags
}
