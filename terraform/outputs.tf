output "jenkins_public_ip" {
  value = module.compute.jenkins_public_ip
}

# App runs on ECS Fargate - access via ALB
output "app_url" {
  value = "http://${module.codedeploy.alb_dns_name}"
}

output "monitoring_public_ip" {
  value = module.monitoring.monitoring_public_ip
}

output "prometheus_url" {
  value = "http://${module.monitoring.monitoring_public_ip}:9090"
}

output "grafana_url" {
  value = "http://${module.monitoring.monitoring_public_ip}:3000"
}

output "cloudtrail_bucket" {
  value = module.security.cloudtrail_bucket
}

output "guardduty_detector_id" {
  value = module.security.guardduty_detector_id
}

output "aws_region" {
  value = var.aws_region
}

# CodeDeploy outputs (conditional)
output "alb_dns_name" {
  value = try(module.codedeploy[0].alb_dns_name, "")
}

output "codedeploy_app_name" {
  value = try(module.codedeploy[0].codedeploy_app_name, "")
}

output "deployment_group_name" {
  value = try(module.codedeploy[0].deployment_group_name, "")
}
