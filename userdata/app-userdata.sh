#!/bin/bash
# TaskFlow App Server UserData
# Note: When using ECS Fargate, this server is minimal - just for monitoring agents

set -euo pipefail

# Update system
yum update -y

# Install Docker (for local testing)
yum install -y docker
systemctl start docker
systemctl enable docker

# Add ec2-user to docker group
usermod -aG docker ec2-user

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

# Install Node.js 18 (for potential local testing)
curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
yum install -y nodejs

echo "App server provisioning complete"
echo "Note: Application runs on ECS Fargate, not this instance"
