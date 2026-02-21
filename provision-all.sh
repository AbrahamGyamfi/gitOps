#!/bin/bash
# Complete Provisioning Script for Hardened CI/CD Pipeline

set -e

echo "🚀 TaskFlow - Complete Infrastructure Provisioning"
echo "=================================================="
echo ""

# Check prerequisites
echo "📋 Checking prerequisites..."

if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform not found. Install from: https://www.terraform.io/downloads"
    exit 1
fi

if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI not found. Install from: https://aws.amazon.com/cli/"
    exit 1
fi

if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ AWS credentials not configured. Run: aws configure"
    exit 1
fi

echo "✅ Prerequisites met"
echo ""

# Get AWS account details
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=${AWS_REGION:-eu-west-1}

echo "📝 Configuration:"
echo "   AWS Account: $AWS_ACCOUNT_ID"
echo "   AWS Region: $AWS_REGION"
echo ""

# Step 1: Create SSH Key Pair
echo "🔑 Step 1: Creating SSH Key Pair..."
if ! aws ec2 describe-key-pairs --key-names taskflow-key --region $AWS_REGION &>/dev/null; then
    aws ec2 create-key-pair \
        --key-name taskflow-key \
        --region $AWS_REGION \
        --query 'KeyMaterial' \
        --output text > taskflow-key.pem
    chmod 400 taskflow-key.pem
    echo "✅ Key pair created: taskflow-key.pem"
else
    echo "✅ Key pair already exists"
fi
echo ""

# Step 2: Configure Terraform
echo "📝 Step 2: Configuring Terraform..."
cd terraform

cat > terraform.tfvars <<EOF
aws_region            = "$AWS_REGION"
project_name          = "taskflow"
environment           = "production"
jenkins_instance_type = "t3.medium"
app_instance_type     = "t3.micro"
key_name              = "taskflow-key"
allowed_ssh_cidr      = "0.0.0.0/0"
EOF

echo "✅ terraform.tfvars created"
echo ""

# Step 3: Initialize Terraform
echo "🔧 Step 3: Initializing Terraform..."
terraform init
echo ""

# Step 4: Plan Infrastructure
echo "📊 Step 4: Planning infrastructure..."
terraform plan -out=tfplan
echo ""

# Step 5: Apply Infrastructure
echo "🚀 Step 5: Provisioning infrastructure..."
read -p "Apply infrastructure? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "❌ Provisioning cancelled"
    exit 1
fi

terraform apply tfplan
echo ""

# Step 6: Get Outputs
echo "📋 Step 6: Retrieving infrastructure details..."
JENKINS_IP=$(terraform output -raw jenkins_public_ip)
APP_IP=$(terraform output -raw app_public_ip)
ALB_DNS=$(terraform output -raw alb_dns_name)
ECR_BACKEND=$(terraform output -raw ecr_backend_repository_url)
ECR_FRONTEND=$(terraform output -raw ecr_frontend_repository_url)
ECS_CLUSTER=$(terraform output -raw ecs_cluster_name)
BACKEND_SERVICE=$(terraform output -raw backend_service_name)
FRONTEND_SERVICE=$(terraform output -raw frontend_service_name)

cd ..

# Step 7: Save Configuration
cat > infrastructure-details.txt <<EOF
TaskFlow Infrastructure Details
================================

Jenkins Server:
  Public IP: $JENKINS_IP
  URL: http://$JENKINS_IP:8080
  SSH: ssh -i taskflow-key.pem ec2-user@$JENKINS_IP
  Initial Password: sudo cat /var/lib/jenkins/secrets/initialAdminPassword

Application Server:
  Public IP: $APP_IP
  SSH: ssh -i taskflow-key.pem ec2-user@$APP_IP

ECS Cluster:
  Cluster: $ECS_CLUSTER
  Backend Service: $BACKEND_SERVICE
  Frontend Service: $FRONTEND_SERVICE

Load Balancer:
  DNS: $ALB_DNS
  Frontend URL: http://$ALB_DNS
  Backend URL: http://$ALB_DNS:5000/health

ECR Repositories:
  Backend: $ECR_BACKEND
  Frontend: $ECR_FRONTEND

AWS Configuration:
  Account ID: $AWS_ACCOUNT_ID
  Region: $AWS_REGION

Next Steps:
1. Wait 2-3 minutes for EC2 user-data scripts to complete
2. Get Jenkins password: ssh -i taskflow-key.pem ec2-user@$JENKINS_IP "sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
3. Access Jenkins: http://$JENKINS_IP:8080
4. Configure Jenkins credentials (see SETUP_JENKINS.md)
5. Create pipeline job pointing to Jenkinsfile.hardened
EOF

echo "✅ Infrastructure details saved to: infrastructure-details.txt"
echo ""

# Display summary
cat infrastructure-details.txt
echo ""

echo "⏳ Waiting for services to initialize (2 minutes)..."
sleep 120

# Step 8: Verify Jenkins
echo "🔍 Step 8: Verifying Jenkins installation..."
if curl -s -o /dev/null -w "%{http_code}" http://$JENKINS_IP:8080 | grep -q "200\|403"; then
    echo "✅ Jenkins is running"
else
    echo "⚠️  Jenkins may still be starting. Check manually."
fi
echo ""

# Step 9: Get Jenkins Password
echo "🔑 Step 9: Retrieving Jenkins initial password..."
JENKINS_PASSWORD=$(ssh -i taskflow-key.pem -o StrictHostKeyChecking=no ec2-user@$JENKINS_IP "sudo cat /var/lib/jenkins/secrets/initialAdminPassword 2>/dev/null" || echo "Not ready yet")
if [ "$JENKINS_PASSWORD" != "Not ready yet" ]; then
    echo "✅ Jenkins Initial Password: $JENKINS_PASSWORD"
    echo "$JENKINS_PASSWORD" > jenkins-initial-password.txt
    echo "   (Saved to: jenkins-initial-password.txt)"
else
    echo "⚠️  Jenkins still initializing. Get password later with:"
    echo "   ssh -i taskflow-key.pem ec2-user@$JENKINS_IP 'sudo cat /var/lib/jenkins/secrets/initialAdminPassword'"
fi
echo ""

echo "✅ =================================================="
echo "✅ PROVISIONING COMPLETE!"
echo "✅ =================================================="
echo ""
echo "📝 Next Steps:"
echo ""
echo "1. Configure Jenkins:"
echo "   - Open: http://$JENKINS_IP:8080"
echo "   - Use password from jenkins-initial-password.txt"
echo "   - Install suggested plugins"
echo ""
echo "2. Add Jenkins Credentials:"
echo "   - Go to: Manage Jenkins → Credentials"
echo "   - Add AWS credentials (ID: aws-credentials)"
echo "   - Add text credential for aws-region: $AWS_REGION"
echo "   - Add text credential for aws-account-id: $AWS_ACCOUNT_ID"
echo ""
echo "3. Create Pipeline Job:"
echo "   - New Item → Pipeline"
echo "   - Pipeline script from SCM"
echo "   - Repository: <your-git-repo>"
echo "   - Script Path: Jenkinsfile.hardened"
echo ""
echo "4. Run Pipeline:"
echo "   - Click 'Build Now'"
echo "   - Monitor security scans"
echo "   - Check deployment to ECS"
echo ""
echo "5. Access Application:"
echo "   - Frontend: http://$ALB_DNS"
echo "   - Backend: http://$ALB_DNS:5000/health"
echo ""
echo "📚 Documentation:"
echo "   - Infrastructure: infrastructure-details.txt"
echo "   - Setup Guide: SETUP_JENKINS.md"
echo "   - Security Pipeline: HARDENED_CICD.md"
echo ""
