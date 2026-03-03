variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "jenkins_instance_type" {
  description = "Instance type for Jenkins server"
  type        = string
  default     = "t3.medium"
}

variable "app_instance_type" {
  description = "Instance type for application server"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "SSH key pair name"
  type        = string
  default     = "taskflow-key"
}

variable "public_key_path" {
  description = "Path to SSH public key"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "private_key_path" {
  description = "Path to SSH private key"
  type        = string
  default     = "~/.ssh/id_rsa"
}

variable "admin_cidr_blocks" {
  description = "Allowed CIDR blocks for administrative endpoints (SSH, Jenkins, Grafana, Prometheus)"
  type        = list(string)
}

variable "cloudtrail_bucket_name" {
  description = "S3 bucket name for CloudTrail logs"
  type        = string
  default     = "taskflow-cloudtrail-logs"
}

variable "vpc_id" {
  description = "VPC ID for ALB"
  type        = string
  default     = "vpc-0b491ab9d139fe84c"
}

variable "subnet_ids" {
  description = "Subnet IDs for ALB and ECS"
  type        = list(string)
  default     = ["subnet-09fd8f27534eeae69", "subnet-07d4be176838dd1d5", "subnet-0bf18bf2083cf053c"]
}

variable "aws_account_id" {
  description = "AWS Account ID"
  type        = string
  default     = "697863031884"
}
