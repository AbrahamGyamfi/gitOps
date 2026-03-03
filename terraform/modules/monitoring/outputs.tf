output "monitoring_instance_id" {
  description = "Monitoring instance ID"
  value       = aws_instance.monitoring.id
}

output "monitoring_public_ip" {
  description = "Monitoring public IP"
  value       = aws_instance.monitoring.public_ip
}

output "monitoring_private_ip" {
  description = "Monitoring private IP"
  value       = aws_instance.monitoring.private_ip
}

output "prometheus_url" {
  description = "Prometheus URL"
  value       = "http://${aws_instance.monitoring.public_ip}:9090"
}

output "grafana_url" {
  description = "Grafana URL"
  value       = "http://${aws_instance.monitoring.public_ip}:3000"
}
