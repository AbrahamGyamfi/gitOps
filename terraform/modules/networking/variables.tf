variable "security_group_name" {
  description = "Name of the security group"
  type        = string
}

variable "key_name" {
  description = "SSH key pair name"
  type        = string
}

variable "public_key_path" {
  description = "Path to SSH public key"
  type        = string
}

variable "admin_cidr_blocks" {
  description = "Allowed CIDR blocks for administrative endpoints"
  type        = list(string)
}
