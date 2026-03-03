#!/bin/bash
set -e

JENKINS_IP="${1}"

if [ -z "$JENKINS_IP" ]; then
  echo "Usage: $0 <jenkins-ip>"
  exit 1
fi

echo "=== Installing Security Tools on Jenkins ==="

ssh -i ~/.ssh/id_rsa ec2-user@$JENKINS_IP << 'EOF'
  sudo rpm -ivh https://github.com/aquasecurity/trivy/releases/download/v0.48.0/trivy_0.48.0_Linux-64bit.rpm || true
  curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sudo sh -s -- -b /usr/local/bin
  wget https://github.com/gitleaks/gitleaks/releases/download/v8.18.1/gitleaks_8.18.1_linux_x64.tar.gz
  tar -xzf gitleaks_8.18.1_linux_x64.tar.gz
  sudo mv gitleaks /usr/local/bin/
  rm gitleaks_8.18.1_linux_x64.tar.gz
  curl -sL https://static.snyk.io/cli/latest/snyk-linux -o snyk
  chmod +x snyk
  sudo mv snyk /usr/local/bin/
  sudo yum install -y jq
  cd ~/sonarqube
  docker-compose up -d
  echo "✅ Tools installed"
EOF

echo "✅ Complete. SonarQube: http://$JENKINS_IP:9000"
