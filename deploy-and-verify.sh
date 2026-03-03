#!/bin/bash
# TaskFlow Deployment and Verification Script

set -euo pipefail

echo "TaskFlow Complete Deployment & Verification"
echo "============================================"

# Step 1: Prerequisites Check
echo ""
echo "[1/9] Checking Prerequisites..."
command -v terraform >/dev/null 2>&1 || { echo "ERROR: Terraform not installed"; exit 1; }
command -v aws >/dev/null 2>&1 || { echo "ERROR: AWS CLI not installed"; exit 1; }
command -v ssh >/dev/null 2>&1 || { echo "ERROR: SSH not installed"; exit 1; }

# Check AWS credentials
aws sts get-caller-identity >/dev/null 2>&1 || { echo "ERROR: AWS credentials not configured"; exit 1; }

# Check SSH key
if [ ! -f ~/.ssh/id_rsa.pub ]; then
    echo "ERROR: SSH public key not found at ~/.ssh/id_rsa.pub"
    echo "Generate one with: ssh-keygen -t rsa -b 4096"
    exit 1
fi

echo "SUCCESS: All prerequisites met"

# Step 2: Deploy Infrastructure
echo ""
echo "[2/9] Deploying Infrastructure with Terraform..."
cd terraform

# Check if terraform.tfvars exists
if [ ! -f terraform.tfvars ]; then
    echo "INFO: Creating terraform.tfvars from example"
    cp terraform.tfvars.example terraform.tfvars
    echo "ERROR: Please edit terraform/terraform.tfvars with your values:"
    echo "  - admin_cidr_blocks (your IP address)"
    echo "  - key_name"
    echo "  - public_key_path"
    echo "  - private_key_path"
    exit 1
fi

echo "INFO: Initializing Terraform"
terraform init -input=false

echo "INFO: Planning deployment"
terraform plan -out=tfplan

echo "INFO: Applying Terraform configuration"
terraform apply -auto-approve tfplan
rm -f tfplan

# Get outputs
JENKINS_IP=$(terraform output -raw jenkins_public_ip)
APP_IP=$(terraform output -raw app_public_ip 2>/dev/null || echo "")
MONITORING_IP=$(terraform output -raw monitoring_public_ip)
PROMETHEUS_URL=$(terraform output -raw prometheus_url)
GRAFANA_URL=$(terraform output -raw grafana_url)
CLOUDTRAIL_BUCKET=$(terraform output -raw cloudtrail_bucket)
GUARDDUTY_ID=$(terraform output -raw guardduty_detector_id)

# CodeDeploy outputs (if enabled)
ALB_DNS=$(terraform output -raw alb_dns_name 2>/dev/null || echo "")
CODEDEPLOY_APP=$(terraform output -raw codedeploy_app_name 2>/dev/null || echo "")
DEPLOYMENT_GROUP=$(terraform output -raw deployment_group_name 2>/dev/null || echo "")

# Determine endpoint
if [ -n "$ALB_DNS" ]; then
    APP_ENDPOINT="http://$ALB_DNS"
    API_ENDPOINT="http://$ALB_DNS:5000"
else
    APP_ENDPOINT="http://$APP_IP"
    API_ENDPOINT="http://$APP_IP:5000"
fi

cd ..

echo "SUCCESS: Infrastructure deployed"
echo "  Jenkins: http://$JENKINS_IP:8080"
if [ -n "$ALB_DNS" ]; then
    echo "  App (ALB): $APP_ENDPOINT"
else
    echo "  App: $APP_ENDPOINT"
fi
echo "  Monitoring: http://$MONITORING_IP:3000"

# Create ECR repositories if they don't exist
echo ""
echo "INFO: Ensuring ECR repositories exist..."
AWS_REGION=$(cd terraform && terraform output -raw aws_region)
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

for REPO in taskflow-backend taskflow-frontend; do
    if aws ecr describe-repositories --repository-names $REPO --region $AWS_REGION >/dev/null 2>&1; then
        echo "INFO: ECR repository $REPO already exists"
    else
        echo "INFO: Creating ECR repository $REPO"
        aws ecr create-repository --repository-name $REPO --region $AWS_REGION >/dev/null
        echo "SUCCESS: Created ECR repository $REPO"
    fi
done

# Step 3: Wait for instances
echo ""
echo "[3/9] Waiting for instances to initialize (120s)..."
sleep 120

if [ -n "$CODEDEPLOY_APP" ]; then
    echo "INFO: Verifying CodeDeploy..."
    aws deploy get-application --application-name "$CODEDEPLOY_APP" >/dev/null 2>&1 && echo "SUCCESS: CodeDeploy ready" || echo "WARNING: CodeDeploy not ready"
    
    if [ -n "$ALB_DNS" ]; then
        echo "INFO: Waiting for ALB (60s)..."
        sleep 60
    fi
fi
echo "SUCCESS: Wait complete"

# Step 4: Verify Services
echo ""
echo "[4/9] Verifying Application Services..."

if curl -sf "$APP_ENDPOINT/health" > /dev/null 2>&1; then
    echo "SUCCESS: App server is healthy"
else
    echo "WARNING: App server not responding yet"
fi

if [ -n "$APP_IP" ] && curl -sf "http://$APP_IP:5000/metrics" > /dev/null 2>&1; then
    echo "SUCCESS: Metrics endpoint working"
else
    echo "WARNING: Metrics not available yet"
fi

# Step 5: Verify Monitoring
echo ""
echo "[5/9] Verifying Monitoring Stack..."

# Check if monitoring containers are running
MONITORING_CONTAINERS=$(ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no ec2-user@$MONITORING_IP "docker ps --format '{{.Names}}'" 2>/dev/null | wc -l)

if [ "$MONITORING_CONTAINERS" -lt 7 ]; then
    echo "WARNING: Only $MONITORING_CONTAINERS containers running, expected 7"
    echo "INFO: Starting monitoring stack..."
    ssh -i ~/.ssh/id_rsa ec2-user@$MONITORING_IP "cd ~/monitoring && docker-compose up -d" || echo "WARNING: Failed to start monitoring stack"
    echo "INFO: Waiting for services to start (60s)..."
    sleep 60
fi

if curl -sf $PROMETHEUS_URL/-/healthy > /dev/null 2>&1; then
    echo "SUCCESS: Prometheus is running"
else
    echo "WARNING: Prometheus not ready yet"
fi

if curl -sf $GRAFANA_URL/api/health > /dev/null 2>&1; then
    echo "SUCCESS: Grafana is running"
else
    echo "WARNING: Grafana not ready yet"
fi

if curl -sf http://$MONITORING_IP:16686 > /dev/null 2>&1; then
    echo "SUCCESS: Jaeger is running"
else
    echo "WARNING: Jaeger not ready yet"
fi

if curl -sf http://$MONITORING_IP:9093/-/healthy > /dev/null 2>&1; then
    echo "SUCCESS: Alertmanager is running"
else
    echo "WARNING: Alertmanager not ready yet"
fi

if curl -sf http://$MONITORING_IP:9100/metrics > /dev/null 2>&1; then
    echo "SUCCESS: Node Exporter is running"
else
    echo "WARNING: Node Exporter not ready yet"
fi

if curl -sf http://$MONITORING_IP:3100/ready > /dev/null 2>&1; then
    echo "SUCCESS: Loki is running"
else
    echo "WARNING: Loki not ready yet (may still be warming up)"
fi

# Step 6: Verify AWS Services
echo ""
echo "[6/9] Verifying AWS Security Services..."

TRAIL_STATUS=$(aws cloudtrail get-trail-status --name taskflow-trail --query 'IsLogging' --output text 2>/dev/null || echo "false")
if [ "$TRAIL_STATUS" = "True" ]; then
    echo "SUCCESS: CloudTrail is logging"
else
    echo "WARNING: CloudTrail not active"
fi

GD_STATUS=$(aws guardduty get-detector --detector-id $GUARDDUTY_ID --query 'Status' --output text 2>/dev/null || echo "DISABLED")
if [ "$GD_STATUS" = "ENABLED" ]; then
    echo "SUCCESS: GuardDuty is enabled"
else
    echo "WARNING: GuardDuty not enabled"
fi

if aws logs describe-log-groups --log-group-name-prefix /aws/taskflow > /dev/null 2>&1; then
    echo "SUCCESS: CloudWatch log group exists"
else
    echo "WARNING: CloudWatch log group not found"
fi

# Step 7: Generate Test Traffic
echo ""
echo "[7/9] Generating Test Traffic..."

for i in {1..10}; do
    curl -sf -X POST "$API_ENDPOINT/api/tasks" \
        -H 'Content-Type: application/json' \
        -d "{\"title\":\"Test Task $i\",\"description\":\"Generated for testing\"}" > /dev/null 2>&1 || true
done
echo "SUCCESS: Created 10 test tasks"

for i in {1..5}; do
    curl -sf "$API_ENDPOINT/api/invalid" > /dev/null 2>&1 || true
done
echo "SUCCESS: Generated error traffic"

# Step 8: Run Observability Validation
echo ""
echo "[8/9] Running Observability Validation..."
echo "INFO: Generating load to trigger alerts (this takes 12 minutes)"
echo "INFO: Phase 1 - Normal traffic (2 min)"
echo "INFO: Phase 2 - High error rate >5% (10 min)"
echo "INFO: Phase 3 - High latency >300ms (10 min)"

TOTAL_REQUESTS=0
PHASE1_END=$(($(date +%s) + 120))
while [ $(date +%s) -lt $PHASE1_END ]; do
    curl -fsS "$API_ENDPOINT/api/tasks" >/dev/null 2>&1 || true
    ((TOTAL_REQUESTS++))
    sleep 0.5
done
echo "INFO: Phase 1 complete - $TOTAL_REQUESTS requests"

PHASE2_END=$(($(date +%s) + 600))
while [ $(date +%s) -lt $PHASE2_END ]; do
    if [ $((RANDOM % 10)) -eq 0 ]; then
        curl -fsS "$API_ENDPOINT/api/test/error?rate=0.1" >/dev/null 2>&1 || true
    else
        curl -fsS "$API_ENDPOINT/api/tasks" >/dev/null 2>&1 || true
    fi
    ((TOTAL_REQUESTS++))
    sleep 0.3
done
echo "INFO: Phase 2 complete - $TOTAL_REQUESTS total requests"

PHASE3_END=$(($(date +%s) + 600))
while [ $(date +%s) -lt $PHASE3_END ]; do
    curl -fsS "$API_ENDPOINT/api/tasks?delay_ms=400" >/dev/null 2>&1 || true
    ((TOTAL_REQUESTS++))
    sleep 0.5
done
echo "SUCCESS: Load generation complete - $TOTAL_REQUESTS total requests"

# Check alerts
ALERTS=$(curl -s "$PROMETHEUS_URL/api/v1/alerts" | grep -o '"alertname":"[^"]*"' | cut -d'"' -f4 || echo "")
if echo "$ALERTS" | grep -q "TaskflowHighErrorRate"; then
    echo "SUCCESS: TaskflowHighErrorRate alert is FIRING"
else
    echo "INFO: TaskflowHighErrorRate alert not firing yet"
fi

if echo "$ALERTS" | grep -q "TaskflowHighLatency"; then
    echo "SUCCESS: TaskflowHighLatency alert is FIRING"
else
    echo "INFO: TaskflowHighLatency alert not firing yet"
fi

# Step 9: Display Summary
echo ""
echo "[9/9] Deployment Summary"
echo "============================================"
echo ""
echo "Application URLs:"
if [ -n "$ALB_DNS" ]; then
    echo "  Frontend:     $APP_ENDPOINT"
    echo "  Backend API:  $API_ENDPOINT"
    echo "  ALB DNS:      $ALB_DNS"
else
    echo "  Frontend:     $APP_ENDPOINT"
    echo "  Backend API:  $API_ENDPOINT"
fi
echo "  Metrics:      http://$APP_IP:5000/metrics"
echo ""
echo "Monitoring URLs:"
echo "  Grafana:      $GRAFANA_URL (admin/check .env file)"
echo "  Prometheus:   $PROMETHEUS_URL"
echo "  Alertmanager: http://$MONITORING_IP:9093"
echo "  Jaeger:       http://$MONITORING_IP:16686"
echo "  Loki:         http://$MONITORING_IP:3100"
echo "  Node Exp:     http://$MONITORING_IP:9100/metrics"
echo ""
echo "CI/CD:"
echo "  Jenkins:      http://$JENKINS_IP:8080"
echo "  Username:     admin"
echo "  Password:     aws ssm get-parameter --region $AWS_REGION --name /taskflow/jenkins-admin-password --with-decryption --query 'Parameter.Value' --output text"
if [ -n "$CODEDEPLOY_APP" ]; then
    echo "  CodeDeploy:   $CODEDEPLOY_APP / $DEPLOYMENT_GROUP"
    echo "  Strategy:     Blue-Green via ALB"
fi
echo ""
echo "Security:"
echo "  CloudTrail:   $CLOUDTRAIL_BUCKET"
echo "  GuardDuty:    $GUARDDUTY_ID"
echo "  CloudWatch:   aws logs tail /aws/taskflow/docker --follow"
echo ""
echo "Validation Steps:"
echo "  1. Open Grafana dashboard: TaskFlow Observability"
echo "  2. Verify error rate >5% and latency >300ms"
echo "  3. Check alerts in Alertmanager"
echo "  4. Click trace link in Grafana to view in Jaeger"
echo "  5. Copy trace_id from Jaeger"
echo "  6. Search Loki logs for trace_id to verify correlation"
echo ""
echo "Cleanup:"
echo "  ./cleanup.sh"
echo ""
echo "SUCCESS: Deployment complete!"
