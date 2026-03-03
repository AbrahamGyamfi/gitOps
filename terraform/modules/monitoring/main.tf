resource "aws_instance" "monitoring" {
  ami                  = var.ami_id
  instance_type        = var.instance_type
  key_name             = var.key_name
  security_groups      = [var.security_group_name]
  iam_instance_profile = var.iam_instance_profile
  user_data = templatefile("${path.root}/../userdata/monitoring-userdata.sh", {
    region    = var.aws_region
    log_group = var.cloudwatch_log_group
  })

  tags = {
    Name        = "TaskFlow-Monitoring-Server"
    Project     = "TaskFlow"
    Environment = "Production"
  }
}

# resource "aws_cloudwatch_log_group" "docker_logs" {
#   name              = var.cloudwatch_log_group
#   retention_in_days = 7

#   tags = {
#     Project = "TaskFlow"
#   }
# }

resource "null_resource" "deploy_monitoring" {
  depends_on = [aws_instance.monitoring]

  triggers = {
    instance_id           = aws_instance.monitoring.id
    app_ip                = var.app_public_ip
    compose_file_sha      = filesha256("${path.root}/../monitoring/docker-compose.yml")
    prometheus_config_sha = filesha256("${path.root}/../monitoring/config/prometheus.yml")
  }

  provisioner "file" {
    source      = "${path.root}/../monitoring"
    destination = "/home/ec2-user/monitoring"

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file(var.private_key_path)
      host        = aws_instance.monitoring.public_ip
    }
  }

  provisioner "remote-exec" {
    inline = [
      "set -e",
      "sudo cloud-init status --wait || true",
      "cd /home/ec2-user/monitoring",
      "sed -i 's/$${APP_PRIVATE_IP}/${var.app_private_ip}/g' config/prometheus.yml",
      "if [ ! -f .env ]; then echo \"GF_SECURITY_ADMIN_PASSWORD=$(openssl rand -base64 32 | tr -d '\\n')\" > .env; chmod 600 .env; fi",
      "sudo systemctl is-active --quiet docker || sudo systemctl start docker",
      "sudo /usr/local/bin/docker-compose --env-file .env up -d",
      "bash -c 'for i in {1..12}; do curl -fsS http://localhost:9090/-/healthy > /dev/null && exit 0; sleep 10; done; echo \"Prometheus health check failed\"; exit 1'",
      "bash -c 'for i in {1..12}; do curl -fsS http://localhost:3000/api/health > /dev/null && exit 0; sleep 10; done; echo \"Grafana health check failed\"; exit 1'"
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file(var.private_key_path)
      host        = aws_instance.monitoring.public_ip
    }
  }
}
