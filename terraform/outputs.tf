output "jenkins_public_ip" {
  description = "Jenkins server public IP"
  value       = module.jenkins.instance_public_ip
}

output "jenkins_url" {
  description = "Jenkins URL"
  value       = "http://${module.jenkins.instance_public_ip}:8080"
}

output "app_public_ip" {
  description = "Application server public IP"
  value       = module.app.instance_public_ip
}

output "app_url" {
  description = "Application URL"
  value       = "http://${module.app.instance_public_ip}"
}

output "security_group_id" {
  description = "Security group ID"
  value       = module.security_group.security_group_id
}

output "ecr_backend_repository_url" {
  description = "ECR backend repository URL"
  value       = module.ecr_backend.repository_url
}

output "ecr_frontend_repository_url" {
  description = "ECR frontend repository URL"
  value       = module.ecr_frontend.repository_url
}

output "ssh_jenkins" {
  description = "SSH command for Jenkins server"
  value       = "ssh -i ${var.key_name}.pem ec2-user@${module.jenkins.instance_public_ip}"
}

output "ssh_app" {
  description = "SSH command for App server"
  value       = "ssh -i ${var.key_name}.pem ec2-user@${module.app.instance_public_ip}"
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.ecs_backend.cluster_name
}

output "alb_dns_name" {
  description = "Application Load Balancer DNS name"
  value       = module.alb.alb_dns_name
}

output "alb_url" {
  description = "Application URL via ALB"
  value       = "http://${module.alb.alb_dns_name}"
}

output "backend_service_name" {
  description = "ECS backend service name"
  value       = module.ecs_backend.service_name
}

output "frontend_service_name" {
  description = "ECS frontend service name"
  value       = module.ecs_frontend.service_name
}
