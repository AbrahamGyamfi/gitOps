variable "app_instance_id" {
  description = "Application instance ID"
  type        = string
}

variable "app_public_ip" {
  description = "Application public IP"
  type        = string
}

variable "monitoring_private_ip" {
  description = "Monitoring server private IP used for OTLP and Loki ingestion"
  type        = string
}

variable "private_key_path" {
  description = "Path to SSH private key"
  type        = string
}

variable "docker_registry" {
  description = "Docker registry URL"
  type        = string
}

variable "image_tag" {
  description = "Docker image tag"
  type        = string
}

variable "aws_region" {
  description = "AWS region for ECR authentication"
  type        = string
}
