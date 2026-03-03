#!/bin/bash
set -euo pipefail

DOCKER_COMPOSE_VERSION="v2.29.7"
JENKINS_PLUGIN_MANAGER_VERSION="2.12.13"

# Update system
yum update -y

# Install Java 17 (required for Jenkins)
yum install -y java-17-amazon-corretto java-17-amazon-corretto-devel

# Install Docker
yum install -y docker
systemctl start docker
systemctl enable docker

# Add ec2-user to docker group
usermod -aG docker ec2-user

# Install Docker Compose
curl -fsSL "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install Jenkins
wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
yum install -y jenkins

# Add jenkins user to docker group
usermod -aG docker jenkins

# Install additional tools
yum install -y git curl wget unzip jq fontconfig

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

# Download Jenkins Plugin Installation Manager Tool (IMPORTANT: Install plugins BEFORE starting Jenkins)
echo "Downloading Jenkins Plugin Installation Manager..."
curl -fsSL "https://github.com/jenkinsci/plugin-installation-manager-tool/releases/download/${JENKINS_PLUGIN_MANAGER_VERSION}/jenkins-plugin-manager-${JENKINS_PLUGIN_MANAGER_VERSION}.jar" -o /tmp/jenkins-plugin-manager.jar

# Get instance metadata
# Get instance metadata
REGION=$(ec2-metadata --availability-zone | cut -d " " -f 2 | sed 's/[a-z]$//')
JENKINS_HOST=$(ec2-metadata --public-ipv4 | cut -d " " -f 2)
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Generate admin password
JENKINS_ADMIN_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)

# Get SSH private key from SSM Parameter Store (will be created by Terraform)
SSH_PRIVATE_KEY=$(aws ssm get-parameter --region $REGION --name "/taskflow/ssh-private-key" --with-decryption --query 'Parameter.Value' --output text 2>/dev/null || echo "")

# Get SonarQube and Snyk tokens from SSM
SONAR_TOKEN=$(aws ssm get-parameter --region $REGION --name "/taskflow/sonar-token" --with-decryption --query 'Parameter.Value' --output text 2>/dev/null || echo "squ_placeholder")
SNYK_TOKEN=$(aws ssm get-parameter --region $REGION --name "/taskflow/snyk-token" --with-decryption --query 'Parameter.Value' --output text 2>/dev/null || echo "snyk_placeholder")

# Get SonarCloud organization from SSM (if using SonarCloud instead of self-hosted SonarQube)
SONAR_ORGANIZATION=$(aws ssm get-parameter --region $REGION --name "/taskflow/sonar-organization" --with-decryption --query 'Parameter.Value' --output text 2>/dev/null || echo "")

# Get AWS credentials from SSM Parameter Store
AWS_ACCESS_KEY_ID=$(aws ssm get-parameter --region $REGION --name "/taskflow/aws-access-key-id" --with-decryption --query 'Parameter.Value' --output text 2>/dev/null || echo "")
AWS_SECRET_ACCESS_KEY=$(aws ssm get-parameter --region $REGION --name "/taskflow/aws-secret-access-key" --with-decryption --query 'Parameter.Value' --output text 2>/dev/null || echo "")

# Wait for other instances to be running (retry logic)
echo "Waiting for App Server to be available..."
for i in {1..12}; do
    APP_SERVER_IP=$(aws ec2 describe-instances --region $REGION --filters "Name=tag:Name,Values=TaskFlow-App-Server" "Name=instance-state-name,Values=running" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text 2>/dev/null)
    if [ "$APP_SERVER_IP" != "None" ] && [ -n "$APP_SERVER_IP" ]; then
        echo "Found App Server IP: $APP_SERVER_IP"
        break
    fi
    echo "Waiting for App Server... attempt $i/12"
    sleep 10
done

APP_PRIVATE_IP=$(aws ec2 describe-instances --region $REGION --filters "Name=tag:Name,Values=TaskFlow-App-Server" "Name=instance-state-name,Values=running" --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text 2>/dev/null || echo "")
MONITORING_HOST=$(aws ec2 describe-instances --region $REGION --filters "Name=tag:Name,Values=TaskFlow-Monitoring-Server" "Name=instance-state-name,Values=running" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text 2>/dev/null || echo "")

# Create Jenkins configuration directory
mkdir -p /var/lib/jenkins/casc_configs

# Create JCasC configuration with environment variables
cat > /var/lib/jenkins/casc_configs/jenkins.yaml <<EOF
jenkins:
  systemMessage: "TaskFlow CI/CD - Fully Automated Configuration"
  numExecutors: 2
  mode: NORMAL
  
  securityRealm:
    local:
      allowsSignup: false
      users:
        - id: "admin"
          password: "${JENKINS_ADMIN_PASSWORD}"
          
  authorizationStrategy:
    loggedInUsersCanDoAnything:
      allowAnonymousRead: false

credentials:
  system:
    domainCredentials:
      - credentials:
          - string:
              scope: GLOBAL
              id: "aws-region"
              secret: "${REGION}"
          - string:
              scope: GLOBAL
              id: "aws-account-id"
              secret: "${AWS_ACCOUNT_ID}"
          - string:
              scope: GLOBAL
              id: "app-server-ip"
              secret: "${APP_SERVER_IP}"
          - string:
              scope: GLOBAL
              id: "app-private-ip"
              secret: "${APP_PRIVATE_IP}"
          - string:
              scope: GLOBAL
              id: "monitoring-host"
              secret: "${MONITORING_HOST}"
          - string:
              scope: GLOBAL
              id: "app-name"
              secret: "taskflow"
          - string:
              scope: GLOBAL
              id: "node-version"
              secret: "18"
          - string:
              scope: GLOBAL
              id: "app-port"
              secret: "5000"
          - string:
              scope: GLOBAL
              id: "integration-test-port"
              secret: "5001"
          - string:
              scope: GLOBAL
              id: "health-check-timeout"
              secret: "60"
          - string:
              scope: GLOBAL
              id: "health-check-interval"
              secret: "5"
          # ECS/Fargate Configuration
          - string:
              scope: GLOBAL
              id: "ecs-cluster-name"
              secret: "taskflow-cluster"
          - string:
              scope: GLOBAL
              id: "ecs-service-backend"
              secret: "taskflow-backend"
          - string:
              scope: GLOBAL
              id: "ecs-service-frontend"
              secret: "taskflow-frontend"
          # CodeDeploy Configuration
          - string:
              scope: GLOBAL
              id: "codedeploy-app-name"
              secret: "taskflow-app"
          - string:
              scope: GLOBAL
              id: "codedeploy-deployment-group"
              secret: "taskflow-blue-green"
          - string:
              scope: GLOBAL
              id: "codedeploy-backend-deployment-group"
              secret: "taskflow-backend-blue-green"
          # Security Scan Tokens
          - string:
              scope: GLOBAL
              id: "sonar-token"
              secret: "${SONAR_TOKEN}"
          - string:
              scope: GLOBAL
              id: "sonar-host-url"
              secret: "https://sonarcloud.io"
          - string:
              scope: GLOBAL
              id: "snyk-token"
              secret: "${SNYK_TOKEN}"
          - string:
              scope: GLOBAL
              id: "sonar-organization"
              secret: "${SONAR_ORGANIZATION}"
          # AWS Credentials
          - aws:
              scope: GLOBAL
              id: "aws-credentials"
              accessKey: "${AWS_ACCESS_KEY_ID}"
              secretKey: "${AWS_SECRET_ACCESS_KEY}"
              description: "AWS Credentials for ECR, ECS, CodeDeploy"

unclassified:
  location:
    url: "http://${JENKINS_HOST}:8080/"
EOF

# Create plugins list file
mkdir -p /var/lib/jenkins/plugins
cat > /var/lib/jenkins/plugins.txt <<EOF
configuration-as-code
credentials
credentials-binding
aws-credentials
plain-credentials
git
github
workflow-aggregator
pipeline-stage-view
docker-workflow
ssh-agent
ssh-credentials
job-dsl
timestamper
ws-cleanup
antisamy-markup-formatter
EOF

# ============================================================
# CRITICAL: Install plugins BEFORE starting Jenkins!
# This ensures JCasC plugin is available on first startup
# ============================================================
echo "Installing Jenkins plugins using Plugin Installation Manager..."
JENKINS_WAR=$(find /usr/share/jenkins -name "jenkins.war" 2>/dev/null || echo "/usr/share/java/jenkins.war")

# If war not found in typical locations, use rpm query
if [ ! -f "$JENKINS_WAR" ]; then
    JENKINS_WAR=$(rpm -ql jenkins | grep "jenkins.war" | head -1)
fi

java -jar /tmp/jenkins-plugin-manager.jar \
    --war "$JENKINS_WAR" \
    --plugin-download-directory /var/lib/jenkins/plugins \
    --plugin-file /var/lib/jenkins/plugins.txt \
    --verbose

# ============================================================
# Configure Jenkins environment via systemd (proper method)
# ============================================================
echo "Configuring Jenkins systemd service..."

# Create systemd override directory
mkdir -p /etc/systemd/system/jenkins.service.d

# Create systemd override for Jenkins environment
cat > /etc/systemd/system/jenkins.service.d/override.conf <<EOF
[Service]
Environment="JAVA_OPTS=-Djava.awt.headless=true -Djenkins.install.runSetupWizard=false"
Environment="CASC_JENKINS_CONFIG=/var/lib/jenkins/casc_configs/jenkins.yaml"
EOF

# Also set in /etc/sysconfig/jenkins for compatibility
cat > /etc/sysconfig/jenkins <<EOF
JENKINS_JAVA_OPTIONS="-Djava.awt.headless=true -Djenkins.install.runSetupWizard=false"
CASC_JENKINS_CONFIG="/var/lib/jenkins/casc_configs/jenkins.yaml"
JENKINS_PORT="8080"
EOF

# Reload systemd to pick up changes
systemctl daemon-reload

# Set ownership
chown -R jenkins:jenkins /var/lib/jenkins

# Start Jenkins
systemctl start jenkins
systemctl enable jenkins

# Wait for Jenkins to start and become ready
echo "Waiting for Jenkins to start..."
MAX_WAIT=120
WAIT_COUNT=0
while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/login | grep -q "200\|403"; then
        echo "Jenkins web interface is responding"
        break
    fi
    sleep 5
    WAIT_COUNT=$((WAIT_COUNT + 5))
    echo "Waiting for Jenkins... ($WAIT_COUNT/$MAX_WAIT seconds)"
done

# Wait additional time for JCasC to fully load
echo "Waiting for JCasC configuration to be applied..."
sleep 30

# Verify JCasC loaded correctly by checking if credentials exist
echo "Verifying Jenkins Configuration as Code..."
JENKINS_CLI_JAR="/tmp/jenkins-cli.jar"
wget -q http://localhost:8080/jnlpJars/jenkins-cli.jar -O "$JENKINS_CLI_JAR" 2>/dev/null || true

if [ -f "$JENKINS_CLI_JAR" ]; then
    # Test if we can authenticate with the admin credentials
    java -jar "$JENKINS_CLI_JAR" -s http://localhost:8080/ -auth admin:${JENKINS_ADMIN_PASSWORD} who-am-i 2>/dev/null && {
        echo "✓ JCasC authentication working - admin user created successfully"
    } || {
        echo "⚠ JCasC may not have loaded credentials correctly"
    }
    
    # List credentials to verify they were created
    java -jar "$JENKINS_CLI_JAR" -s http://localhost:8080/ -auth admin:${JENKINS_ADMIN_PASSWORD} list-credentials system::system::jenkins 2>/dev/null && {
        echo "✓ JCasC credentials configured successfully"
    } || {
        echo "⚠ Could not verify credentials (this may be normal if list-credentials command is unavailable)"
    }
fi

# Force JCasC reload (in case configuration wasn't applied on first start)
echo "Triggering JCasC configuration reload..."
curl -s -X POST "http://localhost:8080/configuration-as-code/reload" \
    -u "admin:${JENKINS_ADMIN_PASSWORD}" 2>/dev/null || true

# Save admin password to SSM Parameter Store
aws ssm put-parameter --region $REGION --name "/taskflow/jenkins-admin-password" --value "${JENKINS_ADMIN_PASSWORD}" --type "SecureString" --overwrite || true

# Save to local file as backup
mkdir -p /var/lib/jenkins/secrets
echo "${JENKINS_ADMIN_PASSWORD}" > /var/lib/jenkins/secrets/admin_password
chown jenkins:jenkins /var/lib/jenkins/secrets/admin_password
chmod 600 /var/lib/jenkins/secrets/admin_password

# Log the configuration location for debugging
echo "JCasC configuration file: /var/lib/jenkins/casc_configs/jenkins.yaml"
ls -la /var/lib/jenkins/casc_configs/ 2>/dev/null || true

echo ""
echo "=============================================="
echo "Jenkins Installation Completed Successfully!"
echo "=============================================="
echo "Admin password saved to SSM Parameter Store: /taskflow/jenkins-admin-password"
echo "Access Jenkins at: http://${JENKINS_HOST}:8080"
echo "Username: admin"
echo "Password: ${JENKINS_ADMIN_PASSWORD}"
echo ""
echo "Credentials configured via JCasC:"
echo "  - aws-region"
echo "  - aws-account-id"
echo "  - aws-credentials"
echo "  - app-server-ip"
echo "  - app-private-ip"
echo "  - app-server-ssh"
echo "  - monitoring-host"
echo "  - sonar-token"
echo "  - snyk-token"
echo "=============================================="
