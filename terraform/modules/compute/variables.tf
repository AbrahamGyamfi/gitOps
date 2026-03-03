variable "jenkins_instance_type" {
  description = "Instance type for Jenkins server"
  type        = string
}

variable "app_instance_type" {
  description = "Instance type for application server"
  type        = string
}

variable "key_name" {
  description = "SSH key pair name"
  type        = string
}

variable "security_group_name" {
  description = "Security group name"
  type        = string
}

variable "app_iam_instance_profile" {
  description = "IAM instance profile attached to the application server"
  type        = string
}

variable "jenkins_iam_instance_profile" {
  description = "IAM instance profile attached to the Jenkins server"
  type        = string
}
