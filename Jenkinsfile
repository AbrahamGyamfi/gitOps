pipeline {
    agent any

    environment {
        AWS_REGION = credentials('aws-region')
        AWS_ACCOUNT_ID = credentials('aws-account-id')
        ECR_REGISTRY = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

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
        disableConcurrentBuilds()
        skipDefaultCheckout(true)
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                sh "mkdir -p ${SCAN_REPORTS_DIR}"
            }
        }

        stage('Secret Scan') {
            steps {
                sh './jenkins/scripts/secret-scan.sh'
            }
        }

        stage('Run Tests') {
            failFast true
            parallel {
                stage('Backend Tests') {
                    steps {
                        sh './jenkins/scripts/test-runner.sh backend'
                    }
                }
                stage('Frontend Tests') {
                    steps {
                        sh './jenkins/scripts/test-runner.sh frontend'
                    }
                }
            }
        }

        stage('SAST - SonarQube') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'sonarqube-credentials',
                    usernameVariable: 'SONAR_USER',
                    passwordVariable: 'SONAR_PASS'
                )]) {
                    sh './jenkins/scripts/sast-scan.sh'
                }
            }
        }

        stage('SCA - OWASP Dependency Check') {
            failFast true
            parallel {
                stage('Backend SCA') {
                    steps {
                        sh './jenkins/scripts/sca-scan.sh taskflow-backend backend backend-sca'
                    }
                }
                stage('Frontend SCA') {
                    steps {
                        sh './jenkins/scripts/sca-scan.sh taskflow-frontend frontend frontend-sca'
                    }
                }
            }
        }

        stage('Build Docker Images') {
            failFast true
            parallel {
                stage('Build Backend') {
                    steps {
                        sh './jenkins/scripts/build-image.sh "${BACKEND_IMAGE}" "${IMAGE_TAG}" ./backend'
                    }
                }
                stage('Build Frontend') {
                    steps {
                        sh './jenkins/scripts/build-image.sh "${FRONTEND_IMAGE}" "${IMAGE_TAG}" ./frontend'
                    }
                }
            }
        }

        stage('Container Security Scanning') {
            failFast true
            parallel {
                stage('Scan Backend Image') {
                    steps {
                        sh './jenkins/scripts/container-scan.sh "${BACKEND_IMAGE}" "${IMAGE_TAG}" backend'
                    }
                }
                stage('Scan Frontend Image') {
                    steps {
                        sh './jenkins/scripts/container-scan.sh "${FRONTEND_IMAGE}" "${IMAGE_TAG}" frontend'
                    }
                }
            }
        }

        stage('Generate SBOM') {
            failFast true
            parallel {
                stage('Backend SBOM') {
                    steps {
                        sh './jenkins/scripts/sbom-generate.sh "${BACKEND_IMAGE}" "${IMAGE_TAG}" backend'
                    }
                }
                stage('Frontend SBOM') {
                    steps {
                        sh './jenkins/scripts/sbom-generate.sh "${FRONTEND_IMAGE}" "${IMAGE_TAG}" frontend'
                    }
                }
            }
        }

        stage('Release to ECS (main/master)') {
            when {
                expression {
                    def branchName = env.BRANCH_NAME ?: env.GIT_BRANCH ?: ''
                    return !env.CHANGE_ID && [
                        'main',
                        'master',
                        'origin/main',
                        'origin/master',
                        'refs/heads/main',
                        'refs/heads/master'
                    ].contains(branchName)
                }
            }
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials']]) {
                    sh './jenkins/scripts/release-ecs.sh'
                }
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: "${SCAN_REPORTS_DIR}/**/*", allowEmptyArchive: true
            sh './jenkins/scripts/local-cleanup.sh'
        }
        success {
            echo "Pipeline completed successfully. Image tag: ${env.IMAGE_TAG}"
        }
        failure {
            echo 'Pipeline failed. Review stage output and security reports.'
        }
    }
}
