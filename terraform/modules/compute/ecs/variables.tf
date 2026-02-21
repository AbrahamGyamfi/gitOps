variable "project_name" {
  description = "Project name"
  type        = string
}

variable "service_name" {
  description = "Service name"
  type        = string
}

variable "cpu" {
  description = "CPU units"
  type        = string
  default     = "256"
}

variable "memory" {
  description = "Memory in MB"
  type        = string
  default     = "512"
}

variable "desired_count" {
  description = "Desired task count"
  type        = number
  default     = 1
}

variable "container_port" {
  description = "Container port"
  type        = number
}

variable "ecr_repository_url" {
  description = "ECR repository URL"
  type        = string
}

variable "execution_role_arn" {
  description = "ECS execution role ARN"
  type        = string
}

variable "task_role_arn" {
  description = "ECS task role ARN"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs"
  type        = list(string)
}

variable "target_group_arn" {
  description = "Target group ARN"
  type        = string
}

variable "alb_security_group_id" {
  description = "ALB security group ID"
  type        = string
}

variable "lb_listener_arn" {
  description = "Load balancer listener ARN"
  type        = string
}

variable "log_group_name" {
  description = "CloudWatch log group name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "environment_variables" {
  description = "Environment variables"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "health_check" {
  description = "Health check configuration"
  type = object({
    command     = list(string)
    interval    = number
    timeout     = number
    retries     = number
    startPeriod = number
  })
  default = null
}

variable "tags" {
  description = "Tags"
  type        = map(string)
  default     = {}
}
