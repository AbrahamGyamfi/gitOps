variable "subnet_ids" {
  description = "Subnet IDs for ECS tasks"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID for ECS tasks"
  type        = string
}

variable "target_group_arn" {
  description = "ALB target group ARN for frontend service"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for service discovery"
  type        = string
}

variable "monitoring_host" {
  description = "Monitoring server private IP for OTLP traces"
  type        = string
}

variable "aws_account_id" {
  description = "AWS Account ID for ECR image URLs"
  type        = string
}

variable "backend_target_group_arn" {
  description = "ALB blue target group ARN for backend CodeDeploy blue/green"
  type        = string
}
