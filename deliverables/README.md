# Project Deliverables - Secure CI/CD Pipeline (ECS + SAST/SCA)

## Overview
This package contains all deliverables for the hardened CI/CD pipeline project deploying to Amazon ECS with comprehensive security scanning.

## Contents

### 1. Jenkinsfile
**Location:** `Jenkinsfile`

Complete CI/CD pipeline configuration with:
- Secret scanning (Gitleaks)
- SAST (Semgrep)
- SCA - Dependency scanning (Trivy)
- Container image scanning (Trivy)
- SBOM generation (Syft/CycloneDX)
- Automated tests (Jest, React Testing Library)
- ECR image push with versioned tags
- ECS task definition registration
- Rolling deployment to ECS Fargate
- Health checks and monitoring
- Automated cleanup

**Quality Gates:**
- Blocks on CRITICAL vulnerabilities in dependencies
- Blocks on CRITICAL vulnerabilities in container images
- Blocks on detected secrets
- SAST warnings (non-blocking)

### 2. ECS Task Definitions
**Location:** `task-definitions/`

- `backend-task-definition.json` - Current backend task definition
- `frontend-task-definition.json` - Current frontend task definition
- `backend-revisions.json` - All backend task definition revisions
- `frontend-revisions.json` - All frontend task definition revisions

**Key Features:**
- Fargate launch type (256 CPU, 512 MB memory)
- CloudWatch Logs integration
- Health checks configured
- Non-root user execution
- Environment variables for configuration
- Versioned container images (build-${BUILD_NUMBER})

### 3. Security Reports
**Location:** `security-reports/`

Generated during pipeline execution and archived as Jenkins artifacts:

- `gitleaks-report.json` - Secret scanning results
- `sast-report.json` - SAST findings (Semgrep)
- `backend-sca.json` - Backend dependency vulnerabilities
- `frontend-sca.json` - Frontend dependency vulnerabilities
- `backend-image-scan.json` - Backend container image vulnerabilities
- `frontend-image-scan.json` - Frontend container image vulnerabilities

**Note:** These reports are generated per build and archived in Jenkins. Sample reports can be downloaded from the latest successful build artifacts.

### 4. SBOM (Software Bill of Materials)
**Location:** `sbom/`

Generated using Syft in CycloneDX JSON format:

- `backend-sbom.json` - Backend application SBOM
- `frontend-sbom.json` - Frontend application SBOM

**Contains:**
- All dependencies and versions
- Package licenses
- Vulnerability references
- Component relationships

**Note:** SBOM files are generated per build and archived in Jenkins artifacts.

### 5. Evidence of ECS Service Updates
**Location:** `evidence/`

- `ecs-services-status.json` - Current ECS services state
- `running-tasks.json` - Active ECS tasks
- `backend-images.json` - Recent backend images in ECR
- `frontend-images.json` - Recent frontend images in ECR
- `deployment-logs.txt` - Sample deployment logs

## Pipeline Execution Flow

1. **Checkout** - Clone repository
2. **Secret Scanning** - Gitleaks scan (blocks on findings)
3. **SAST** - Semgrep code analysis (warning mode)
4. **SCA** - Trivy dependency scan (blocks on CRITICAL)
5. **Build** - Docker images with layer caching
6. **Image Scanning** - Trivy container scan (blocks on CRITICAL)
7. **SBOM Generation** - Syft creates software bill of materials
8. **Tests** - Backend and frontend unit tests
9. **Push to ECR** - Versioned and latest tags
10. **Deploy to ECS** - Register new task definitions and update services
11. **Wait for Deployment** - ECS services-stable wait (10 min timeout)
12. **Health Check** - ALB endpoint verification
13. **Cleanup** - Old images and task definitions

## Infrastructure

**AWS Resources:**
- ECS Cluster: `taskflow-cluster` (Fargate)
- Services: `taskflow-backend-service`, `taskflow-frontend-service`
- ECR Repositories: `taskflow-backend`, `taskflow-frontend`
- ALB: `taskflow-alb` with target groups
- CloudWatch Log Groups: `/ecs/taskflow/backend`, `/ecs/taskflow/frontend`
- IAM Roles: ECS execution and task roles

**Terraform Modules:**
- `compute/` - EC2, ECR, ECS
- `networking/` - ALB, CloudWatch
- `security/` - IAM, Security Groups

## Security Features

✅ Secret scanning with Gitleaks
✅ SAST with Semgrep
✅ SCA with Trivy (dependencies)
✅ Container image scanning with Trivy
✅ SBOM generation with Syft
✅ Quality gates block on CRITICAL findings
✅ Non-root container execution
✅ Minimal Alpine base images
✅ Multi-stage builds (frontend)
✅ ECR image scanning enabled
✅ CloudWatch logging for audit trail

## Performance Optimizations

- Docker layer caching for faster builds
- Parallel execution of scans and tests
- npm ci for deterministic installs
- Multi-stage builds to reduce image size
- Automated cleanup of old resources

## Image Sizes

- Backend: ~65 MB (node:18-alpine)
- Frontend: ~25 MB (nginx:alpine with React build)

## Deployment Evidence

The pipeline successfully:
1. Registers new ECS task definitions with versioned image tags
2. Updates ECS services with rolling deployment
3. Waits for services to stabilize
4. Verifies health endpoints
5. Cleans up old task definitions (keeps last 5)

## Access Information

- **Jenkins URL:** http://34.254.178.139:8080
- **ALB URL:** http://taskflow-alb-1427958729.eu-west-1.elb.amazonaws.com
- **AWS Region:** eu-west-1
- **AWS Account:** 697863031884

## Build Artifacts

All security reports and SBOM files are archived as Jenkins build artifacts and can be downloaded from:
- Jenkins → Job → Build #X → Build Artifacts → security-reports/

## Verification

To verify the deployment:

```bash
# Check ECS services
aws ecs describe-services --cluster taskflow-cluster \
  --services taskflow-backend-service taskflow-frontend-service \
  --region eu-west-1

# Check running tasks
aws ecs list-tasks --cluster taskflow-cluster --region eu-west-1

# Test health endpoint
curl http://taskflow-alb-1427958729.eu-west-1.elb.amazonaws.com:5000/health

# View CloudWatch logs
aws logs tail /ecs/taskflow/backend --follow --region eu-west-1
```

## Project Structure

```
GitOps_CICD_Hardening/
├── Jenkinsfile                    # CI/CD pipeline
├── backend/
│   ├── Dockerfile                 # Backend container
│   ├── package.json
│   └── server.js
├── frontend/
│   ├── Dockerfile                 # Frontend container (multi-stage)
│   ├── nginx.conf
│   ├── package.json
│   └── src/
├── terraform/
│   ├── main.tf
│   └── modules/
│       ├── compute/               # EC2, ECR, ECS
│       ├── networking/            # ALB, CloudWatch
│       └── security/              # IAM, Security Groups
└── deliverables/                  # This package
    ├── Jenkinsfile
    ├── task-definitions/
    ├── evidence/
    └── README.md
```

## Date Generated
February 21, 2026

## Version
Build #5 (latest successful deployment)
