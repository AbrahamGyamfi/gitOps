output "security_group_id" {
  description = "Security group ID"
  value       = aws_security_group.taskflow.id
}

output "security_group_name" {
  description = "Security group name"
  value       = aws_security_group.taskflow.name
}

output "key_name" {
  description = "SSH key pair name"
  value       = aws_key_pair.taskflow.key_name
}

output "vpc_id" {
  description = "Default VPC ID"
  value       = aws_security_group.taskflow.vpc_id
}

output "subnet_ids" {
  description = "Default subnet IDs"
  value       = data.aws_subnets.default.ids
}
