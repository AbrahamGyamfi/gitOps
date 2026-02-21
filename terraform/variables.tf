variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "taskflow"
}

variable "environment" {
  description = "Environment"
  type        = string
  default     = "production"
}

variable "jenkins_instance_type" {
  description = "Jenkins server instance type"
  type        = string
  default     = "t3.medium"
}

variable "app_instance_type" {
  description = "Application server instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "SSH key pair name"
  type        = string
  default     = "taskflow-key"
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed for SSH access"
  type        = string
  default     = "0.0.0.0/0"
}
