variable "ami_id" {
  description = "AMI ID for monitoring instance"
  type        = string
}

variable "instance_type" {
  description = "Instance type for monitoring server"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "SSH key pair name"
  type        = string
}

variable "security_group_name" {
  description = "Security group name"
  type        = string
}

variable "iam_instance_profile" {
  description = "IAM instance profile for CloudWatch"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "cloudwatch_log_group" {
  description = "CloudWatch log group name"
  type        = string
  default     = "/aws/taskflow/docker"
}

variable "app_public_ip" {
  description = "Application server public IP"
  type        = string
}

variable "app_private_ip" {
  description = "Application server private IP"
  type        = string
}

variable "private_key_path" {
  description = "Path to SSH private key"
  type        = string
}
