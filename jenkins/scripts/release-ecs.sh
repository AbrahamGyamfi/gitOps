#!/usr/bin/env bash
set -euo pipefail

: "${AWS_REGION:?AWS_REGION is required}"
: "${ECR_REGISTRY:?ECR_REGISTRY is required}"
: "${BACKEND_IMAGE:?BACKEND_IMAGE is required}"
: "${FRONTEND_IMAGE:?FRONTEND_IMAGE is required}"
: "${IMAGE_TAG:?IMAGE_TAG is required}"
: "${ECS_CLUSTER:?ECS_CLUSTER is required}"
: "${ECS_BACKEND_SERVICE:?ECS_BACKEND_SERVICE is required}"
: "${ECS_FRONTEND_SERVICE:?ECS_FRONTEND_SERVICE is required}"
: "${ECS_BACKEND_TASK_FAMILY:=taskflow-backend}"
: "${ECS_FRONTEND_TASK_FAMILY:=taskflow-frontend}"
: "${ECS_BACKEND_CONTAINER:=taskflow-backend}"
: "${ECS_FRONTEND_CONTAINER:=taskflow-frontend}"
: "${ALB_NAME:=taskflow-alb}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Logging in to ECR..."
aws ecr get-login-password --region "${AWS_REGION}" | \
docker login --username AWS --password-stdin "${ECR_REGISTRY}"

echo "Pushing images..."
docker push "${BACKEND_IMAGE}:${IMAGE_TAG}"
docker push "${BACKEND_IMAGE}:latest"
docker push "${FRONTEND_IMAGE}:${IMAGE_TAG}"
docker push "${FRONTEND_IMAGE}:latest"

echo "Deploying ECS services..."
"${SCRIPT_DIR}/ecs-deploy.sh" \
    "${ECS_BACKEND_SERVICE}" \
    "${ECS_BACKEND_TASK_FAMILY}" \
    "${BACKEND_IMAGE}:${IMAGE_TAG}" \
    "${ECS_BACKEND_CONTAINER}"

"${SCRIPT_DIR}/ecs-deploy.sh" \
    "${ECS_FRONTEND_SERVICE}" \
    "${ECS_FRONTEND_TASK_FAMILY}" \
    "${FRONTEND_IMAGE}:${IMAGE_TAG}" \
    "${ECS_FRONTEND_CONTAINER}"

echo "Waiting for ECS services to stabilize..."
aws ecs wait services-stable \
    --cluster "${ECS_CLUSTER}" \
    --services "${ECS_BACKEND_SERVICE}" "${ECS_FRONTEND_SERVICE}" \
    --region "${AWS_REGION}"

echo "Running health checks..."
ALB_DNS="$(aws elbv2 describe-load-balancers \
    --names "${ALB_NAME}" \
    --query 'LoadBalancers[0].DNSName' \
    --output text \
    --region "${AWS_REGION}")"

for i in {1..3}; do
    if curl -fsS --max-time 10 "http://${ALB_DNS}/health" >/dev/null || \
       curl -fsS --max-time 10 "http://${ALB_DNS}:5000/health" >/dev/null; then
        echo "Health check passed"
        break
    fi

    if [ "${i}" -eq 3 ]; then
        echo "Health check failed after 3 attempts"
        exit 1
    fi

    sleep 15
done

echo "Cleaning old active task definitions (keeping 5 latest)..."
for FAMILY in "${ECS_BACKEND_TASK_FAMILY}" "${ECS_FRONTEND_TASK_FAMILY}"; do
    OLD_TASKS="$(aws ecs list-task-definitions \
        --family-prefix "${FAMILY}" \
        --status ACTIVE \
        --sort DESC \
        --region "${AWS_REGION}" \
        --query 'taskDefinitionArns[5:]' \
        --output text)"

    if [ -z "${OLD_TASKS}" ] || [ "${OLD_TASKS}" = "None" ]; then
        continue
    fi

    for TASK_ARN in ${OLD_TASKS}; do
        aws ecs deregister-task-definition \
            --task-definition "${TASK_ARN}" \
            --region "${AWS_REGION}" || true
    done
done
