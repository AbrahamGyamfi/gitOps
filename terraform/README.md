# Terraform Infrastructure for TaskFlow

This directory contains Terraform configuration to provision AWS infrastructure for the TaskFlow application.

## Prerequisites

1. **Terraform** installed (>= 1.0)
2. **AWS CLI** configured with credentials
3. **SSH Key Pair** created in AWS (or create one below)

## Quick Start

### 1. Create SSH Key Pair (if needed)

```bash
aws ec2 create-key-pair \
  --key-name taskflow-key \
  --region eu-west-1 \
  --query 'KeyMaterial' \
  --output text > taskflow-key.pem

chmod 400 taskflow-key.pem
```

### 2. Configure Variables

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

### 3. Initialize Terraform

```bash
terraform init
```

### 4. Plan Infrastructure

```bash
terraform plan
```

### 5. Apply Infrastructure

```bash
terraform apply
```

### 6. Get Outputs

```bash
terraform output
```

## Resources Created

- **2 EC2 Instances**: Jenkins server (t3.medium) + App server (t3.micro)
- **1 Security Group**: Ports 22, 80, 5000, 8080
- **2 ECR Repositories**: taskflow-backend, taskflow-frontend

## Outputs

- `jenkins_public_ip` - Jenkins server IP
- `jenkins_url` - Jenkins web interface URL
- `app_public_ip` - Application server IP
- `app_url` - Application URL
- `ecr_backend_repository_url` - Backend ECR URL
- `ecr_frontend_repository_url` - Frontend ECR URL
- `ssh_jenkins` - SSH command for Jenkins
- `ssh_app` - SSH command for App server

## Destroy Infrastructure

```bash
terraform destroy
```

## Notes

- Wait 2-3 minutes after apply for user data scripts to complete
- Get Jenkins initial password: `sudo cat /var/lib/jenkins/secrets/initialAdminPassword`
- Update Jenkinsfile with new ECR repository URLs from outputs
