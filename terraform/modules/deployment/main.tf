resource "null_resource" "deploy_app" {
  depends_on = [var.app_instance_id]

  triggers = {
    instance_id           = var.app_instance_id
    image_tag             = var.image_tag
    docker_registry       = var.docker_registry
    aws_region            = var.aws_region
    monitoring_private_ip = var.monitoring_private_ip
    compose_file_sha      = filesha256("${path.root}/../docker-compose.yml")
    promtail_config_sha   = filesha256("${path.root}/../monitoring/config/promtail-app.yml")
  }

  provisioner "file" {
    source      = "${path.root}/../docker-compose.yml"
    destination = "/home/ec2-user/docker-compose.yml"

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file(var.private_key_path)
      host        = var.app_public_ip
    }
  }

  provisioner "file" {
    source      = "${path.root}/../monitoring/config/promtail-app.yml"
    destination = "/home/ec2-user/promtail-config.yml"

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file(var.private_key_path)
      host        = var.app_public_ip
    }
  }

  provisioner "remote-exec" {
    inline = [
      "set -e",
      "echo 'Waiting for cloud-init to complete...'",
      "sudo cloud-init status --wait || true",
      "echo 'Waiting for Docker to be ready...'",
      "for i in {1..30}; do sudo systemctl is-active --quiet docker && break || sleep 2; done",
      "sudo systemctl start docker || true",
      "sleep 5",
      "echo 'Configuring Promtail...'",
      "sed -i 's/MONITORING_PRIVATE_IP/${var.monitoring_private_ip}/g' /home/ec2-user/promtail-config.yml",
      "sed -i 's/APP_PUBLIC_IP/${var.app_public_ip}/g' /home/ec2-user/promtail-config.yml",
      "echo 'Creating environment file...'",
      "printf 'REGISTRY_URL=%s\\nIMAGE_TAG=%s\\nAWS_REGION=%s\\nMONITORING_HOST=%s\\n' '${var.docker_registry}' '${var.image_tag}' '${var.aws_region}' '${var.monitoring_private_ip}' > /home/ec2-user/.taskflow.env",
      "echo 'Starting Node Exporter...'",
      "sudo docker rm -f node-exporter 2>/dev/null || true",
      "sudo docker run -d --name node-exporter --restart unless-stopped -p 9100:9100 prom/node-exporter:v1.8.2",
      "echo 'Checking if ECR images exist...'",
      "aws ecr get-login-password --region ${var.aws_region} | sudo docker login --username AWS --password-stdin ${var.docker_registry} || { echo 'ECR login failed - skipping image pull'; exit 0; }",
      "if aws ecr describe-images --repository-name taskflow-backend --region ${var.aws_region} --image-ids imageTag=${var.image_tag} >/dev/null 2>&1; then",
      "  echo 'Pulling Docker images...'",
      "  sudo docker pull ${var.docker_registry}/taskflow-backend:${var.image_tag}",
      "  sudo docker pull ${var.docker_registry}/taskflow-frontend:${var.image_tag}",
      "  echo 'Stopping existing containers...'",
      "  sudo /usr/local/bin/docker-compose --env-file /home/ec2-user/.taskflow.env -f /home/ec2-user/docker-compose.yml down 2>/dev/null || true",
      "  echo 'Starting application containers...'",
      "  sudo /usr/local/bin/docker-compose --env-file /home/ec2-user/.taskflow.env -f /home/ec2-user/docker-compose.yml up -d",
      "  echo 'Starting Promtail...'",
      "  sudo docker rm -f promtail 2>/dev/null || true",
      "  sudo docker run -d --name promtail --restart unless-stopped -v /var/lib/docker/containers:/var/lib/docker/containers:ro -v /var/run/docker.sock:/var/run/docker.sock:ro -v /home/ec2-user/promtail-config.yml:/etc/promtail/config.yml:ro grafana/promtail:3.1.1 -config.file=/etc/promtail/config.yml",
      "  echo 'Verifying Promtail...'",
      "  for i in {1..12}; do sudo docker ps --filter name=promtail --filter status=running --format '{{.Names}}' | grep -q promtail && break || sleep 5; done",
      "  echo 'Waiting for application health check...'",
      "  for i in {1..30}; do curl -fsS http://localhost/health > /dev/null 2>&1 && { echo 'Application is healthy'; break; } || sleep 10; done",
      "else",
      "  echo 'INFO: ECR images not found - skipping application deployment'",
      "  echo 'INFO: Run Jenkins pipeline to build and deploy application'",
      "fi",
      "echo 'Verifying Node Exporter...'",
      "for i in {1..12}; do sudo docker ps --filter name=node-exporter --filter status=running --format '{{.Names}}' | grep -q node-exporter && break || sleep 5; done",
      "echo 'Deployment provisioning complete'",
      "sudo docker ps",
      "exit 0"
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file(var.private_key_path)
      host        = var.app_public_ip
    }
  }
}
