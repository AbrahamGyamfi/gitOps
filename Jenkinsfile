pipeline {
    agent any
    
    environment {
        AWS_REGION = credentials('aws-region')
        AWS_ACCOUNT_ID = credentials('aws-account-id')
        ECR_REGISTRY = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        AWS_CREDENTIALS_ID = 'aws-credentials'
        
        BACKEND_IMAGE = "${ECR_REGISTRY}/taskflow-backend"
        FRONTEND_IMAGE = "${ECR_REGISTRY}/taskflow-frontend"
        IMAGE_TAG = "build-${BUILD_NUMBER}"
        
        ECS_CLUSTER = 'taskflow-cluster'
        ECS_BACKEND_SERVICE = 'taskflow-backend-service'
        ECS_FRONTEND_SERVICE = 'taskflow-frontend-service'
        
        SCAN_REPORTS_DIR = 'security-reports'
    }
    
    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timestamps()
        timeout(time: 45, unit: 'MINUTES')
    }
    
    stages {
        stage('Checkout') {
            steps {
                script {
                    echo '📥 Checking out code...'
                    checkout scm
                    sh "mkdir -p ${SCAN_REPORTS_DIR}"
                }
            }
        }
        
        stage('Secret Scanning') {
            steps {
                script {
                    echo '🔐 Scanning for secrets with Gitleaks...'
                    sh '''
                        docker run --rm -v $(pwd):/repo zricethezav/gitleaks:latest \
                            detect --source /repo --report-path /repo/${SCAN_REPORTS_DIR}/gitleaks-report.json \
                            --no-git --verbose || true
                        
                        if [ -f ${SCAN_REPORTS_DIR}/gitleaks-report.json ]; then
                            if [ $(cat ${SCAN_REPORTS_DIR}/gitleaks-report.json | jq '. | length') -gt 0 ]; then
                                echo "❌ SECRETS DETECTED! Pipeline blocked."
                                cat ${SCAN_REPORTS_DIR}/gitleaks-report.json
                                exit 1
                            fi
                        fi
                        echo "✅ No secrets detected"
                    '''
                }
            }
        }
        
        stage('SAST - Semgrep') {
            steps {
                script {
                    echo '🔍 Running SAST with Semgrep...'
                    sh '''
                        docker run --rm -v $(pwd):/src returntocorp/semgrep \
                            semgrep scan --config=auto --json \
                            --output ${SCAN_REPORTS_DIR}/sast-report.json /src || true
                        
                        if [ -f ${SCAN_REPORTS_DIR}/sast-report.json ]; then
                            CRITICAL=$(cat ${SCAN_REPORTS_DIR}/sast-report.json | jq '[.results[] | select(.extra.severity=="ERROR")] | length')
                            echo "SAST - Critical: $CRITICAL"
                            
                            # Warning only - don't block for now
                            if [ "$CRITICAL" -gt 0 ]; then
                                echo "⚠️  WARNING: $CRITICAL CRITICAL security issues found in code!"
                                echo "Review security-reports/sast-report.json"
                            fi
                        fi
                        echo "✅ SAST scan completed"
                    '''
                }
            }
        }
        
        stage('SCA - Dependency Check') {
            parallel {
                stage('Backend SCA') {
                    steps {
                        script {
                            echo '📦 Scanning backend dependencies...'
                            dir('backend') {
                                sh '''
                                    docker run --rm -v $(pwd):/src \
                                        aquasec/trivy fs --severity HIGH,CRITICAL \
                                        --format json --output /src/../${SCAN_REPORTS_DIR}/backend-sca.json \
                                        /src/package.json || true
                                    
                                    if [ -f ../${SCAN_REPORTS_DIR}/backend-sca.json ]; then
                                        CRITICAL=$(cat ../${SCAN_REPORTS_DIR}/backend-sca.json | jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="CRITICAL")] | length')
                                        HIGH=$(cat ../${SCAN_REPORTS_DIR}/backend-sca.json | jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="HIGH")] | length')
                                        
                                        echo "Backend - Critical: $CRITICAL, High: $HIGH"
                                        
                                        if [ "$CRITICAL" -gt 0 ]; then
                                            echo "❌ CRITICAL vulnerabilities found in backend dependencies!"
                                            exit 1
                                        fi
                                    fi
                                '''
                            }
                        }
                    }
                }
                
                stage('Frontend SCA') {
                    steps {
                        script {
                            echo '📦 Scanning frontend dependencies...'
                            dir('frontend') {
                                sh '''
                                    docker run --rm -v $(pwd):/src \
                                        aquasec/trivy fs --severity HIGH,CRITICAL \
                                        --format json --output /src/../${SCAN_REPORTS_DIR}/frontend-sca.json \
                                        /src/package.json || true
                                    
                                    if [ -f ../${SCAN_REPORTS_DIR}/frontend-sca.json ]; then
                                        CRITICAL=$(cat ../${SCAN_REPORTS_DIR}/frontend-sca.json | jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="CRITICAL")] | length')
                                        HIGH=$(cat ../${SCAN_REPORTS_DIR}/frontend-sca.json | jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="HIGH")] | length')
                                        
                                        echo "Frontend - Critical: $CRITICAL, High: $HIGH"
                                        
                                        if [ "$CRITICAL" -gt 0 ]; then
                                            echo "❌ CRITICAL vulnerabilities found in frontend dependencies!"
                                            exit 1
                                        fi
                                    fi
                                '''
                            }
                        }
                    }
                }
            }
        }
        
        stage('Build Docker Images') {
            parallel {
                stage('Build Backend') {
                    steps {
                        script {
                            echo '🔨 Building backend Docker image...'
                            dir('backend') {
                                sh '''
                                    docker build \
                                        --build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
                                        --build-arg BUILD_NUMBER=${BUILD_NUMBER} \
                                        -t ${BACKEND_IMAGE}:${IMAGE_TAG} \
                                        -t ${BACKEND_IMAGE}:latest \
                                        .
                                '''
                            }
                        }
                    }
                }
                
                stage('Build Frontend') {
                    steps {
                        script {
                            echo '🔨 Building frontend Docker image...'
                            dir('frontend') {
                                sh '''
                                    docker build \
                                        --build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
                                        --build-arg BUILD_NUMBER=${BUILD_NUMBER} \
                                        -t ${FRONTEND_IMAGE}:${IMAGE_TAG} \
                                        -t ${FRONTEND_IMAGE}:latest \
                                        .
                                '''
                            }
                        }
                    }
                }
            }
        }
        
        stage('Container Image Scanning') {
            parallel {
                stage('Scan Backend Image') {
                    steps {
                        script {
                            echo '🐳 Scanning backend container image...'
                            sh '''
                                docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
                                    aquasec/trivy image --severity HIGH,CRITICAL \
                                    --format json --output ${SCAN_REPORTS_DIR}/backend-image-scan.json \
                                    ${BACKEND_IMAGE}:${IMAGE_TAG} || true
                                
                                if [ -f ${SCAN_REPORTS_DIR}/backend-image-scan.json ]; then
                                    CRITICAL=$(cat ${SCAN_REPORTS_DIR}/backend-image-scan.json | jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="CRITICAL")] | length')
                                    
                                    echo "Backend Image - Critical: $CRITICAL"
                                    
                                    if [ "$CRITICAL" -gt 0 ]; then
                                        echo "❌ CRITICAL vulnerabilities in backend image!"
                                        exit 1
                                    fi
                                fi
                            '''
                        }
                    }
                }
                
                stage('Scan Frontend Image') {
                    steps {
                        script {
                            echo '🐳 Scanning frontend container image...'
                            sh '''
                                docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
                                    aquasec/trivy image --severity HIGH,CRITICAL \
                                    --format json --output ${SCAN_REPORTS_DIR}/frontend-image-scan.json \
                                    ${FRONTEND_IMAGE}:${IMAGE_TAG} || true
                                
                                if [ -f ${SCAN_REPORTS_DIR}/frontend-image-scan.json ]; then
                                    CRITICAL=$(cat ${SCAN_REPORTS_DIR}/frontend-image-scan.json | jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="CRITICAL")] | length')
                                    
                                    echo "Frontend Image - Critical: $CRITICAL"
                                    
                                    if [ "$CRITICAL" -gt 0 ]; then
                                        echo "❌ CRITICAL vulnerabilities in frontend image!"
                                        exit 1
                                    fi
                                fi
                            '''
                        }
                    }
                }
            }
        }
        
        stage('Generate SBOM') {
            parallel {
                stage('Backend SBOM') {
                    steps {
                        script {
                            echo '📋 Generating backend SBOM...'
                            sh '''
                                docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
                                    anchore/syft:latest ${BACKEND_IMAGE}:${IMAGE_TAG} \
                                    -o cyclonedx-json=${SCAN_REPORTS_DIR}/backend-sbom.json
                            '''
                        }
                    }
                }
                
                stage('Frontend SBOM') {
                    steps {
                        script {
                            echo '📋 Generating frontend SBOM...'
                            sh '''
                                docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
                                    anchore/syft:latest ${FRONTEND_IMAGE}:${IMAGE_TAG} \
                                    -o cyclonedx-json=${SCAN_REPORTS_DIR}/frontend-sbom.json
                            '''
                        }
                    }
                }
            }
        }
        
        stage('Run Tests') {
            parallel {
                stage('Backend Tests') {
                    steps {
                        script {
                            echo '🧪 Running backend tests...'
                            dir('backend') {
                                sh '''
                                    docker run --rm -v "${WORKSPACE}/backend":/app -w /app node:18-alpine sh -c '
                                        npm install
                                        npm test
                                    '
                                '''
                            }
                        }
                    }
                }
                
                stage('Frontend Tests') {
                    steps {
                        script {
                            echo '🧪 Running frontend tests...'
                            dir('frontend') {
                                sh '''
                                    docker run --rm -v "${WORKSPACE}/frontend":/app -w /app node:18-alpine sh -c '
                                        npm install --legacy-peer-deps
                                        CI=true npm test -- --passWithNoTests
                                    '
                                '''
                            }
                        }
                    }
                }
            }
        }
        
        stage('Push to ECR') {
            steps {
                script {
                    echo '📤 Pushing images to ECR...'
                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: env.AWS_CREDENTIALS_ID]]) {
                        sh '''
                            aws ecr get-login-password --region $AWS_REGION | \
                            docker login --username AWS --password-stdin $ECR_REGISTRY
                            
                            docker push $BACKEND_IMAGE:$IMAGE_TAG
                            docker push $BACKEND_IMAGE:latest
                            
                            docker push $FRONTEND_IMAGE:$IMAGE_TAG
                            docker push $FRONTEND_IMAGE:latest
                        '''
                    }
                }
            }
        }
        
        stage('Deploy to ECS') {
            steps {
                script {
                    echo '🚀 Updating ECS task definitions with new image tags...'
                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: env.AWS_CREDENTIALS_ID]]) {
                        sh '''
                            # Get current backend task definition
                            BACKEND_TASK_DEF=$(aws ecs describe-task-definition \
                                --task-definition taskflow-backend \
                                --region $AWS_REGION \
                                --query 'taskDefinition' | \
                                jq --arg IMAGE "$BACKEND_IMAGE:$IMAGE_TAG" \
                                '.containerDefinitions[0].image = $IMAGE | del(.taskDefinitionArn, .revision, .status, .requiresAttributes, .compatibilities, .registeredAt, .registeredBy)')
                            
                            # Register new backend task definition
                            NEW_BACKEND_TASK=$(echo $BACKEND_TASK_DEF | \
                                aws ecs register-task-definition \
                                --cli-input-json file:///dev/stdin \
                                --region $AWS_REGION \
                                --query 'taskDefinition.taskDefinitionArn' \
                                --output text)
                            
                            echo "✅ Registered backend task: $NEW_BACKEND_TASK"
                            
                            # Get current frontend task definition
                            FRONTEND_TASK_DEF=$(aws ecs describe-task-definition \
                                --task-definition taskflow-frontend \
                                --region $AWS_REGION \
                                --query 'taskDefinition' | \
                                jq --arg IMAGE "$FRONTEND_IMAGE:$IMAGE_TAG" \
                                '.containerDefinitions[0].image = $IMAGE | del(.taskDefinitionArn, .revision, .status, .requiresAttributes, .compatibilities, .registeredAt, .registeredBy)')
                            
                            # Register new frontend task definition
                            NEW_FRONTEND_TASK=$(echo $FRONTEND_TASK_DEF | \
                                aws ecs register-task-definition \
                                --cli-input-json file:///dev/stdin \
                                --region $AWS_REGION \
                                --query 'taskDefinition.taskDefinitionArn' \
                                --output text)
                            
                            echo "✅ Registered frontend task: $NEW_FRONTEND_TASK"
                            
                            # Update backend service with new task definition
                            aws ecs update-service \
                                --cluster $ECS_CLUSTER \
                                --service $ECS_BACKEND_SERVICE \
                                --task-definition $NEW_BACKEND_TASK \
                                --region $AWS_REGION
                            
                            # Update frontend service with new task definition
                            aws ecs update-service \
                                --cluster $ECS_CLUSTER \
                                --service $ECS_FRONTEND_SERVICE \
                                --task-definition $NEW_FRONTEND_TASK \
                                --region $AWS_REGION
                            
                            echo "🚀 ECS services updated with new task definitions"
                        '''
                    }
                }
            }
        }
        
        stage('Wait for Deployment') {
            steps {
                script {
                    echo '⏳ Waiting for ECS deployment...'
                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: env.AWS_CREDENTIALS_ID]]) {
                        timeout(time: 10, unit: 'MINUTES') {
                            sh '''
                                aws ecs wait services-stable \
                                    --cluster $ECS_CLUSTER \
                                    --services $ECS_BACKEND_SERVICE $ECS_FRONTEND_SERVICE \
                                    --region $AWS_REGION || {
                                        echo "⚠️  Deployment taking longer than expected, checking status..."
                                        aws ecs describe-services --cluster $ECS_CLUSTER \
                                            --services $ECS_BACKEND_SERVICE $ECS_FRONTEND_SERVICE \
                                            --region $AWS_REGION \
                                            --query 'services[].[serviceName,runningCount,desiredCount]' \
                                            --output table
                                        exit 1
                                    }
                            '''
                        }
                    }
                }
            }
        }
        
        stage('Health Check') {
            steps {
                script {
                    echo '🏥 Running health checks...'
                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: env.AWS_CREDENTIALS_ID]]) {
                        sh '''
                            ALB_DNS=$(aws elbv2 describe-load-balancers \
                                --names taskflow-alb \
                                --query 'LoadBalancers[0].DNSName' \
                                --output text \
                                --region $AWS_REGION)
                            
                            for i in {1..10}; do
                                if curl -f http://$ALB_DNS:5000/health; then
                                    echo "✅ Health check passed"
                                    break
                                fi
                                sleep 10
                            done
                        '''
                    }
                }
            }
        }
    }
    
    post {
        always {
            archiveArtifacts artifacts: "${SCAN_REPORTS_DIR}/**/*", allowEmptyArchive: true
            script {
                echo '🧹 Cleaning up old Docker images and ECS task definitions...'
                sh "docker image prune -f && docker container prune -f"
                
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: env.AWS_CREDENTIALS_ID]]) {
                    sh '''
                        # Clean up old ECS task definitions (keep last 5)
                        for FAMILY in taskflow-backend taskflow-frontend; do
                            OLD_TASKS=$(aws ecs list-task-definitions \
                                --family-prefix $FAMILY \
                                --status ACTIVE \
                                --sort DESC \
                                --region $AWS_REGION \
                                --query 'taskDefinitionArns[5:]' \
                                --output text)
                            
                            for TASK_ARN in $OLD_TASKS; do
                                echo "Deregistering old task: $TASK_ARN"
                                aws ecs deregister-task-definition \
                                    --task-definition $TASK_ARN \
                                    --region $AWS_REGION || true
                            done
                        done
                        
                        echo "✅ Cleanup completed"
                    '''
                }
            }
        }
        
        success {
            echo "✅ Pipeline completed! Images: ${env.IMAGE_TAG}"
        }
        
        failure {
            echo "❌ Pipeline failed! Check security reports."
        }
    }
}
