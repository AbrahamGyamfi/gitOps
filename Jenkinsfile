#!/usr/bin/env groovy

// ============================================================================
// SHARED LIBRARY FUNCTIONS
// ============================================================================

def ecrLogin() {
    sh """
        aws ecr get-login-password --region \${AWS_REGION} | \
        docker login --username AWS --password-stdin \
        \${AWS_ACCOUNT_ID}.dkr.ecr.\${AWS_REGION}.amazonaws.com
    """
}

def buildDockerImage(String component, String imageTag) {
    dir(component) {
        sh """
            docker pull \${AWS_ACCOUNT_ID}.dkr.ecr.\${AWS_REGION}.amazonaws.com/\${APP_NAME}-${component}:latest || true
            DOCKER_BUILDKIT=0 docker build \
                --cache-from \${AWS_ACCOUNT_ID}.dkr.ecr.\${AWS_REGION}.amazonaws.com/\${APP_NAME}-${component}:latest \
                --build-arg BUILD_DATE=\$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
                --build-arg VCS_REF=\${GIT_COMMIT} \
                --build-arg BUILD_NUMBER=\${BUILD_NUMBER} \
                --network=host \
                -t \${AWS_ACCOUNT_ID}.dkr.ecr.\${AWS_REGION}.amazonaws.com/\${APP_NAME}-${component}:${imageTag} .
        """
    }
}

def pushDockerImage(String component, String imageTag) {
    sh """
        docker push \${AWS_ACCOUNT_ID}.dkr.ecr.\${AWS_REGION}.amazonaws.com/\${APP_NAME}-${component}:${imageTag}
        docker tag \${AWS_ACCOUNT_ID}.dkr.ecr.\${AWS_REGION}.amazonaws.com/\${APP_NAME}-${component}:${imageTag} \
                   \${AWS_ACCOUNT_ID}.dkr.ecr.\${AWS_REGION}.amazonaws.com/\${APP_NAME}-${component}:latest
        docker push \${AWS_ACCOUNT_ID}.dkr.ecr.\${AWS_REGION}.amazonaws.com/\${APP_NAME}-${component}:latest
    """
}

def runSecurityScan(String scanType, String target = '') {
    def scanScripts = [
        'gitleaks': './security-scans/gitleaks-scan.sh',
        'sonar': './security-scans/sonarqube-scan.sh AbrahamGyamfi_Advance_monitoring_Jaeger .',
        'snyk': "./security-scans/snyk-scan.sh ${target}",
        'trivy': "./security-scans/trivy-scan.sh \${AWS_ACCOUNT_ID}.dkr.ecr.\${AWS_REGION}.amazonaws.com/\${APP_NAME}-${target}:${IMAGE_TAG} ${target}",
        'sbom': "./security-scans/sbom-generate.sh \${AWS_ACCOUNT_ID}.dkr.ecr.\${AWS_REGION}.amazonaws.com/\${APP_NAME}-${target}:${IMAGE_TAG} ${target}"
    ]
    
    sh "chmod +x security-scans/*.sh"
    sh scanScripts[scanType]
}

def runTests(String component, String testType) {
    dir(component) {
        def npmInstall = component == 'frontend' ? 'npm ci --legacy-peer-deps' : 'npm ci'
        def testCmd = testType == 'unit' ? 'CI=true npm test -- --passWithNoTests' : 'npm run lint'
        
        sh """
            docker run --rm -v \$(pwd):/app -w /app node:\${NODE_VERSION}-alpine \
                sh -c '${npmInstall} && ${testCmd}'
        """
    }
}

def deployToECS(String component, String containerPort) {
    def taskDefFile = "ecs-task-definition-${component}.json"
    def appspecFile = "appspec-${component}.yaml"
    def deploymentGroup = component == 'frontend' ? env.CODEDEPLOY_GROUP : env.CODEDEPLOY_BACKEND_GROUP
    
    sh """
        # Stop any existing in-progress deployment for this deployment group
        echo "Checking for existing deployments on ${deploymentGroup}..."
        EXISTING_DEPLOYMENT=\$(aws deploy list-deployments \
            --application-name \${CODEDEPLOY_APP} \
            --deployment-group-name ${deploymentGroup} \
            --include-only-statuses InProgress \
            --region \${AWS_REGION} \
            --query 'deployments[0]' --output text 2>/dev/null || echo "None")
        
        if [ "\$EXISTING_DEPLOYMENT" != "None" ] && [ -n "\$EXISTING_DEPLOYMENT" ]; then
            echo "WARNING: Stopping existing deployment: \$EXISTING_DEPLOYMENT"
            aws deploy stop-deployment --deployment-id \$EXISTING_DEPLOYMENT --region \${AWS_REGION} --auto-rollback-enabled || true
            sleep 5
        fi

        # Resolve monitoring host IP from Terraform outputs or EC2 tag
        MONITORING_HOST=\$(aws ec2 describe-instances \
            --region \${AWS_REGION} \
            --filters "Name=tag:Name,Values=taskflow-monitoring" "Name=instance-state-name,Values=running" \
            --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text)
        if [ -z "\$MONITORING_HOST" ] || [ "\$MONITORING_HOST" = "None" ]; then
            echo "WARNING: Monitoring instance not found — using fallback"
            MONITORING_HOST="127.0.0.1"
        fi
        echo "Monitoring host IP: \$MONITORING_HOST"

        # Register task definition — inject IMAGE_TAG and MONITORING_HOST
        sed -e 's/IMAGE_TAG/${IMAGE_TAG}/g' -e "s/MONITORING_HOST/\$MONITORING_HOST/g" ${taskDefFile} > ${taskDefFile.replace('.json', '')}-${IMAGE_TAG}.json
        TASK_ARN=\$(aws ecs register-task-definition \
            --cli-input-json file://${taskDefFile.replace('.json', '')}-${IMAGE_TAG}.json \
            --region \${AWS_REGION} \
            --query 'taskDefinition.taskDefinitionArn' --output text)
        echo "${component.capitalize()} task definition: \$TASK_ARN"

        # Get network configuration
        SG=\$(aws ecs describe-services --cluster \${ECS_CLUSTER} --services taskflow-${component} \
            --region \${AWS_REGION} --query 'services[0].networkConfiguration.awsvpcConfiguration.securityGroups[0]' --output text)
        SUBNET0=\$(aws ecs describe-services --cluster \${ECS_CLUSTER} --services taskflow-${component} \
            --region \${AWS_REGION} --query 'services[0].networkConfiguration.awsvpcConfiguration.subnets[0]' --output text)
        SUBNET1=\$(aws ecs describe-services --cluster \${ECS_CLUSTER} --services taskflow-${component} \
            --region \${AWS_REGION} --query 'services[0].networkConfiguration.awsvpcConfiguration.subnets[1]' --output text)

        # Generate AppSpec
        cat > ${appspecFile} <<EOF
version: 0.0
Resources:
  - TargetService:
      Type: AWS::ECS::Service
      Properties:
        TaskDefinition: "\$TASK_ARN"
        LoadBalancerInfo:
          ContainerName: "taskflow-${component}"
          ContainerPort: ${containerPort}
        PlatformVersion: "LATEST"
        NetworkConfiguration:
          AwsvpcConfiguration:
            AssignPublicIp: ENABLED
            SecurityGroups: ["\$SG"]
            Subnets: ["\$SUBNET0", "\$SUBNET1"]
EOF

        # Create deployment using S3 revision
        S3_BUCKET="taskflow-codedeploy-697863031884"
        S3_KEY="appspec-${component}-\${BUILD_NUMBER}.yaml"
        aws s3 cp ${appspecFile} s3://\${S3_BUCKET}/\${S3_KEY} --region \${AWS_REGION}
        
        DEPLOYMENT_ID=\$(aws deploy create-deployment \
            --application-name \${CODEDEPLOY_APP} \
            --deployment-group-name ${deploymentGroup} \
            --s3-location bucket=\${S3_BUCKET},key=\${S3_KEY},bundleType=YAML \
            --region \${AWS_REGION} \
            --query 'deploymentId' --output text)
        echo "SUCCESS: ${component.capitalize()} deployment: \$DEPLOYMENT_ID"

        # Persist deployment ID so Wait stage can track it
        echo "\$DEPLOYMENT_ID" > deployment-id-${component}.txt
    """
}

def getAWSCredentials() {
    return [
        [$class: 'AmazonWebServicesCredentialsBinding', credentialsId: env.AWS_CREDENTIALS_ID],
        string(credentialsId: 'aws-region', variable: 'AWS_REGION'),
        string(credentialsId: 'aws-account-id', variable: 'AWS_ACCOUNT_ID'),
        string(credentialsId: 'app-name', variable: 'APP_NAME')
    ]
}

def performHealthCheck(String albUrl, int maxRetries = 30, int intervalSec = 10) {
    // All checks use port 80 - nginx proxies /api/* and /health to backend internally
    def endpoints = [
        [name: 'Frontend', url: "${albUrl}/", expectedStatus: 200],
        [name: 'Backend Health (via proxy)', url: "${albUrl}/health", expectedStatus: 200],
        [name: 'Backend API (via proxy)', url: "${albUrl}/api/tasks", expectedStatus: 200]
    ]
    
    endpoints.each { endpoint ->
        echo "Checking ${endpoint.name} at ${endpoint.url}..."
        def success = false
        for (int i = 1; i <= maxRetries && !success; i++) {
            try {
                def response = sh(
                    script: "curl -s -o /dev/null -w '%{http_code}' --connect-timeout 10 ${endpoint.url}",
                    returnStdout: true
                ).trim()
                if (response == "${endpoint.expectedStatus}") {
                    echo "SUCCESS: ${endpoint.name}: HTTP ${response}"
                    success = true
                } else {
                    echo "WAITING: ${endpoint.name}: HTTP ${response} (attempt ${i}/${maxRetries})"
                    if (i < maxRetries) sleep(intervalSec)
                }
            } catch (Exception e) {
                echo "WAITING: ${endpoint.name}: Connection failed (attempt ${i}/${maxRetries})"
                if (i < maxRetries) sleep(intervalSec)
            }
        }
        if (!success) {
            error "FAILED: ${endpoint.name} health check failed after ${maxRetries} attempts"
        }
    }
    echo "SUCCESS: All health checks passed!"
}

// ============================================================================
// PIPELINE DEFINITION
// ============================================================================

pipeline {
    agent any
    
    triggers {
        githubPush()
    }
    
    environment {
        AWS_CREDENTIALS_ID = 'aws-credentials'
        IMAGE_TAG = "${BUILD_NUMBER}"
        BUILD_START_TIME = "${System.currentTimeMillis()}"
    }
    
    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timestamps()
        timeout(time: 30, unit: 'MINUTES')
    }
    
    stages {
        stage('Checkout') {
            steps {
                script {
                    echo 'Checking out code...'
                    checkout scm
                    env.GIT_COMMIT_MSG = sh(script: 'git log -1 --pretty=%B', returnStdout: true).trim()
                    env.GIT_AUTHOR = sh(script: 'git log -1 --pretty=%an', returnStdout: true).trim()
                    echo "Commit: ${env.GIT_COMMIT_MSG}"
                    echo "Author: ${env.GIT_AUTHOR}"
                }
            }
        }
        
        stage('Security Scans') {
            parallel {
                stage('Secret Scan') {
                    steps {
                        script {
                            echo 'Scanning for secrets with Gitleaks...'
                            runSecurityScan('gitleaks')
                        }
                    }
                }
                stage('SAST Scan') {
                    steps {
                        script {
                            echo 'Running SonarCloud SAST...'
                            withCredentials([
                                string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN'),
                                string(credentialsId: 'sonar-organization', variable: 'SONAR_ORGANIZATION')
                            ]) {
                                runSecurityScan('sonar')
                            }
                        }
                    }
                }
                stage('SCA Scan') {
                    steps {
                        script {
                            echo 'Running Snyk SCA...'
                            withCredentials([string(credentialsId: 'snyk-token', variable: 'SNYK_TOKEN')]) {
                                runSecurityScan('snyk', 'backend')
                                runSecurityScan('snyk', 'frontend')
                            }
                        }
                    }
                }
            }
        }
        
        stage('Code Quality') {
            steps {
                script {
                    echo 'Running code quality checks...'
                    withCredentials([string(credentialsId: 'node-version', variable: 'NODE_VERSION')]) {
                        parallel(
                            backendLint: { runTests('backend', 'lint') },
                            frontendLint: { runTests('frontend', 'lint') }
                        )
                    }
                }
            }
        }
        
        stage('Run Unit Tests') {
            steps {
                script {
                    echo 'Running unit tests...'
                    withCredentials([string(credentialsId: 'node-version', variable: 'NODE_VERSION')]) {
                        parallel(
                            backend: { runTests('backend', 'unit') },
                            frontend: { runTests('frontend', 'unit') }
                        )
                    }
                }
            }
        }
        
        stage('Build Docker Images') {
            steps {
                script {
                    echo 'Building Docker images with layer caching...'
                    withCredentials(getAWSCredentials()) {
                        ecrLogin()
                        parallel(
                            backend: { buildDockerImage('backend', IMAGE_TAG) },
                            frontend: { buildDockerImage('frontend', IMAGE_TAG) }
                        )
                    }
                }
            }
        }
        
        stage('Container Security Scan') {
            steps {
                script {
                    echo 'Scanning images with Trivy...'
                    withCredentials(getAWSCredentials()) {
                        parallel(
                            backend: { runSecurityScan('trivy', 'backend') },
                            frontend: { runSecurityScan('trivy', 'frontend') }
                        )
                    }
                }
            }
        }
        
        stage('Generate SBOM') {
            steps {
                script {
                    echo 'Generating SBOM...'
                    withCredentials(getAWSCredentials()) {
                        parallel(
                            backend: { runSecurityScan('sbom', 'backend') },
                            frontend: { runSecurityScan('sbom', 'frontend') }
                        )
                    }
                }
            }
        }
        
        stage('Image Verification') {
            steps {
                script {
                    echo 'Verifying built images...'
                    withCredentials(getAWSCredentials()) {
                        sh """
                            docker run --rm \${AWS_ACCOUNT_ID}.dkr.ecr.\${AWS_REGION}.amazonaws.com/\${APP_NAME}-backend:${IMAGE_TAG} node --version
                            docker run --rm \${AWS_ACCOUNT_ID}.dkr.ecr.\${AWS_REGION}.amazonaws.com/\${APP_NAME}-frontend:${IMAGE_TAG} nginx -v
                        """
                    }
                }
            }
        }
        
        stage('Integration Tests') {
            steps {
                script {
                    echo 'Running integration tests...'
                    withCredentials(getAWSCredentials() + [
                        string(credentialsId: 'app-port', variable: 'APP_PORT'),
                        string(credentialsId: 'integration-test-port', variable: 'INTEGRATION_TEST_PORT'),
                        string(credentialsId: 'health-check-timeout', variable: 'HEALTH_CHECK_TIMEOUT'),
                        string(credentialsId: 'health-check-interval', variable: 'HEALTH_CHECK_INTERVAL')
                    ]) {
                        sh '''
                            set -euo pipefail
                            CONTAINER_NAME="test-backend-${BUILD_NUMBER}"
                            cleanup() { docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true; }
                            trap cleanup EXIT
                            cleanup
                            docker run -d --name "$CONTAINER_NAME" -p ${INTEGRATION_TEST_PORT}:${APP_PORT} \
                                "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${APP_NAME}-backend:${BUILD_NUMBER}"
                            MAX_ITERATIONS=$((${HEALTH_CHECK_TIMEOUT} / ${HEALTH_CHECK_INTERVAL}))
                            for i in $(seq 1 $MAX_ITERATIONS); do
                                if curl -fsS http://localhost:${INTEGRATION_TEST_PORT}/health >/dev/null 2>&1; then break; fi
                                if [ "$i" -eq "$MAX_ITERATIONS" ]; then docker logs "$CONTAINER_NAME"; exit 1; fi
                                sleep ${HEALTH_CHECK_INTERVAL}
                            done
                            curl -fsS http://localhost:${INTEGRATION_TEST_PORT}/api/tasks
                            echo "Integration tests passed!"
                        '''
                    }
                }
            }
        }
        
        stage('Push to ECR') {
            steps {
                script {
                    echo 'Pushing images to ECR...'
                    withCredentials(getAWSCredentials()) {
                        ecrLogin()
                        parallel(
                            backend: { pushDockerImage('backend', IMAGE_TAG) },
                            frontend: { pushDockerImage('frontend', IMAGE_TAG) }
                        )
                    }
                }
            }
        }
        
        stage('Deploy via CodeDeploy') {
            steps {
                script {
                    echo 'Deploying via CodeDeploy Blue-Green...'
                    withCredentials(getAWSCredentials() + [
                        string(credentialsId: 'codedeploy-app-name', variable: 'CODEDEPLOY_APP'),
                        string(credentialsId: 'codedeploy-deployment-group', variable: 'CODEDEPLOY_GROUP'),
                        string(credentialsId: 'codedeploy-backend-deployment-group', variable: 'CODEDEPLOY_BACKEND_GROUP'),
                        string(credentialsId: 'ecs-cluster-name', variable: 'ECS_CLUSTER')
                    ]) {
                        parallel(
                            frontend: { deployToECS('frontend', '80') },
                            backend: { deployToECS('backend', '5000') }
                        )
                    }
                }
            }
        }
        
        stage('Wait for Deployment') {
            steps {
                script {
                    echo 'Waiting for CodeDeploy deployments to complete...'
                    withCredentials(getAWSCredentials() + [
                        string(credentialsId: 'ecs-cluster-name', variable: 'ECS_CLUSTER')
                    ]) {
                        timeout(time: 15, unit: 'MINUTES') {
                            sh '''
                                set -euo pipefail

                                for component in frontend backend; do
                                    DEPLOY_ID=$(cat deployment-id-${component}.txt 2>/dev/null || echo "")
                                    if [ -z "$DEPLOY_ID" ]; then
                                        echo "ERROR: No deployment ID found for $component"
                                        exit 1
                                    fi

                                    echo "Waiting for $component deployment: $DEPLOY_ID"
                                    while true; do
                                        DEP_STATUS=$(aws deploy get-deployment \
                                            --deployment-id "$DEPLOY_ID" \
                                            --region ${AWS_REGION} \
                                            --query 'deploymentInfo.status' --output text)

                                        echo "  $component ($DEPLOY_ID): $DEP_STATUS"

                                        case $DEP_STATUS in
                                            Succeeded)
                                                echo "SUCCESS: $component deployment completed"
                                                break
                                                ;;
                                            Failed|Stopped)
                                                echo "FAILED: $component deployment $DEP_STATUS"
                                                aws deploy get-deployment \
                                                    --deployment-id "$DEPLOY_ID" \
                                                    --region ${AWS_REGION} \
                                                    --query 'deploymentInfo.errorInformation' --output json || true
                                                exit 1
                                                ;;
                                            *)
                                                sleep 10
                                                ;;
                                        esac
                                    done
                                done

                                echo ""
                                echo "=== Final ECS Service Status ==="
                                aws ecs describe-services \
                                    --cluster ${ECS_CLUSTER} \
                                    --services taskflow-frontend taskflow-backend \
                                    --region ${AWS_REGION} \
                                    --query 'services[*].[serviceName,status,runningCount,desiredCount]' \
                                    --output table

                                echo "All deployments completed successfully"
                            '''
                        }
                    }
                }
            }
        }
        
        stage('Health Check') {
            steps {
                script {
                    echo 'Verifying ALB endpoints...'
                    withCredentials(getAWSCredentials()) {
                        def albDns = sh(
                            script: '''
                                aws elbv2 describe-load-balancers \
                                    --names taskflow-alb \
                                    --region ${AWS_REGION} \
                                    --query 'LoadBalancers[0].DNSName' \
                                    --output text
                            ''',
                            returnStdout: true
                        ).trim()
                        echo "ALB DNS: ${albDns}"
                        performHealthCheck("http://${albDns}", 6, 5)
                    }
                }
            }
        }

    }
    
    post {
        always {
            script {
                echo 'Archiving artifacts and cleaning up...'
                archiveArtifacts artifacts: 'trivy-*-report.json,sbom-*.json,gitleaks-report.json,snyk-*-report.json,ecs-task-definition-*-*.json', allowEmptyArchive: true
                
                sh """
                    docker rm -f test-backend-${BUILD_NUMBER} 2>/dev/null || true
                    docker container prune -f
                    docker image prune -f
                    find backend/node_modules frontend/node_modules -type d -exec chmod 755 {} + 2>/dev/null || true
                    find backend/node_modules frontend/node_modules -type f -exec chmod 644 {} + 2>/dev/null || true
                    rm -rf backend/node_modules frontend/node_modules 2>/dev/null || true
                    echo "Disk usage: \$(df -h / | tail -1)"
                """
                
                try {
                    def duration = (System.currentTimeMillis() - env.BUILD_START_TIME.toLong()) / 1000
                    echo "Total build duration: ${duration}s (${duration/60}m)"
                } catch (Exception e) {
                    echo "Could not calculate build duration"
                }
            }
        }
        success {
            script {
                def duration = (System.currentTimeMillis() - env.BUILD_START_TIME.toLong()) / 1000
                echo """
==================================
PIPELINE COMPLETED SUCCESSFULLY!
==================================
Duration: ${duration}s (${duration/60}m)
Build: #${BUILD_NUMBER}
Deployed via CodeDeploy Blue-Green
Application URL: http://taskflow-alb-2078476769.eu-west-1.elb.amazonaws.com
                """.trim()
            }
        }
        failure {
            script {
                def duration = (System.currentTimeMillis() - env.BUILD_START_TIME.toLong()) / 1000
                echo """
==================================
PIPELINE FAILED!
==================================
Duration: ${duration}s
Build: #${BUILD_NUMBER}
Check logs: ${BUILD_URL}console
                """.trim()
            }
        }
    }
}
