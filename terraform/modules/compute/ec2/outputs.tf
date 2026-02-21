output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.this.id
}

output "instance_public_ip" {
  description = "EC2 instance public IP"
  value       = aws_instance.this.public_ip
}
