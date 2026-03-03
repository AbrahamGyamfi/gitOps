output "jenkins_instance_id" {
  description = "Jenkins instance ID"
  value       = aws_instance.jenkins.id
}

output "jenkins_public_ip" {
  description = "Jenkins public IP"
  value       = aws_instance.jenkins.public_ip
}

# App outputs removed - using ECS Fargate instead
# output "app_instance_id" {
#   description = "App instance ID"
#   value       = aws_instance.app.id
# }

# output "app_public_ip" {
#   description = "App public IP"
#   value       = aws_instance.app.public_ip
# }

# output "app_private_ip" {
#   description = "App private IP"
#   value       = aws_instance.app.private_ip
# }

output "ami_id" {
  description = "AMI ID used for instances"
  value       = data.aws_ami.amazon_linux_2.id
}
