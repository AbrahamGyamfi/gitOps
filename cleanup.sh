#!/bin/bash
set -euo pipefail

SSH_KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/id_rsa}"
AWS_REGION="${AWS_REGION:-eu-west-1}"

echo "TaskFlow Resource Cleanup"
echo "============================="
echo ""

# Get Terraform outputs
cd terraform
APP_IP=$(terraform output -raw app_public_ip 2>/dev/null || echo "")
JENKINS_IP=$(terraform output -raw jenkins_public_ip 2>/dev/null || echo "")
CLOUDTRAIL_BUCKET=$(terraform output -raw cloudtrail_bucket 2>/dev/null || echo "")
cd ..

# Stop application containers
if [ -n "$APP_IP" ] && [ -f "$SSH_KEY_PATH" ]; then
    echo "Stopping application containers on $APP_IP..."
    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -i "$SSH_KEY_PATH" ec2-user@$APP_IP << 'EOF' || true
docker-compose down -v 2>/dev/null || true
docker stop $(docker ps -aq) 2>/dev/null || true
docker rm $(docker ps -aq) 2>/dev/null || true
docker system prune -af --volumes 2>/dev/null || true
EOF
    echo "Application containers stopped"
fi

# Clean Jenkins workspace
if [ -n "$JENKINS_IP" ] && [ -f "$SSH_KEY_PATH" ]; then
    echo "Cleaning Jenkins workspace on $JENKINS_IP..."
    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -i "$SSH_KEY_PATH" ec2-user@$JENKINS_IP << 'EOF' || true
sudo systemctl stop jenkins 2>/dev/null || true
docker system prune -af --volumes 2>/dev/null || true
EOF
    echo "Jenkins cleaned"
fi

# Empty CloudTrail S3 bucket
if [ -n "$CLOUDTRAIL_BUCKET" ]; then
    echo "Emptying CloudTrail S3 bucket: $CLOUDTRAIL_BUCKET..."
    aws s3 rm s3://$CLOUDTRAIL_BUCKET --recursive --region $AWS_REGION 2>/dev/null || true
    echo "S3 bucket emptied"
fi

# Delete ECR repositories
echo "Deleting ECR repositories..."
aws ecr delete-repository --repository-name taskflow-backend --force --region $AWS_REGION 2>/dev/null || true
aws ecr delete-repository --repository-name taskflow-frontend --force --region $AWS_REGION 2>/dev/null || true
echo "ECR repositories deleted"

# Destroy Terraform resources
echo ""
echo "Destroying Terraform infrastructure..."
echo "============================="
cd terraform
terraform destroy -auto-approve

echo ""
echo "All resources destroyed successfully!"
echo ""
echo "Cleaned up:"
echo "  - Application containers"
echo "  - Monitoring stack"
echo "  - Jenkins workspace"
echo "  - CloudTrail S3 bucket"
echo "  - ECR repositories"
echo "  - EC2 instances"
echo "  - Security groups"
echo "  - IAM roles"
echo "  - CloudWatch log groups"
