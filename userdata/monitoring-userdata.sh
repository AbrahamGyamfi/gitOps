#!/bin/bash
set -euo pipefail

DOCKER_COMPOSE_VERSION="v2.29.7"

# Update system
yum update -y

# Install Docker
yum install -y docker
systemctl start docker
systemctl enable docker
usermod -aG docker ec2-user

# Install Docker Compose
curl -fsSL "https://github.com/docker/compose/releases/download/$${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install CloudWatch agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
rpm -U ./amazon-cloudwatch-agent.rpm

# Ensure openssl is available for secure secret generation
yum install -y openssl

# Configure Docker logging to CloudWatch
cat > /etc/docker/daemon.json <<DOCKER
{
  "log-driver": "awslogs",
  "log-opts": {
    "awslogs-region": "${region}",
    "awslogs-group": "${log_group}",
    "awslogs-create-group": "true"
  }
}
DOCKER

systemctl restart docker

# Pre-pull monitoring images to speed up deployment
echo "Pre-pulling Docker images..."
docker pull prom/prometheus:latest &
docker pull grafana/grafana:latest &
docker pull prom/alertmanager:latest &
docker pull jaegertracing/all-in-one:latest &
docker pull grafana/loki:latest &
docker pull grafana/promtail:latest &
wait

echo "Monitoring server setup completed!"
