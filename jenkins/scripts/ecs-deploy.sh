#!/usr/bin/env bash
set -euo pipefail

SERVICE_NAME="${1:?Usage: ecs-deploy.sh <service> <task-family> <image-uri> <container-name>}"
TASK_FAMILY="${2:?Usage: ecs-deploy.sh <service> <task-family> <image-uri> <container-name>}"
IMAGE_URI="${3:?Usage: ecs-deploy.sh <service> <task-family> <image-uri> <container-name>}"
CONTAINER_NAME="${4:?Usage: ecs-deploy.sh <service> <task-family> <image-uri> <container-name>}"

: "${AWS_REGION:?AWS_REGION is required}"
: "${ECS_CLUSTER:?ECS_CLUSTER is required}"

TMP_DIR="$(mktemp -d "/tmp/ecs-deploy-${TASK_FAMILY}-XXXXXX")"
trap 'rm -rf "${TMP_DIR}"' EXIT

TASK_JSON="${TMP_DIR}/task.json"
TASK_NEW_JSON="${TMP_DIR}/task-new.json"

echo "Deploying ${SERVICE_NAME} using ${TASK_FAMILY} -> ${IMAGE_URI}"

aws ecs describe-task-definition \
    --task-definition "${TASK_FAMILY}" \
    --region "${AWS_REGION}" \
    --query 'taskDefinition' > "${TASK_JSON}"

jq -e --arg CONTAINER "${CONTAINER_NAME}" \
    '.containerDefinitions[] | select(.name == $CONTAINER)' \
    "${TASK_JSON}" >/dev/null

jq --arg IMAGE "${IMAGE_URI}" --arg CONTAINER "${CONTAINER_NAME}" \
    'del(.taskDefinitionArn, .revision, .status, .requiresAttributes, .compatibilities, .registeredAt, .registeredBy) |
    (.containerDefinitions[] | select(.name == $CONTAINER) | .image) = $IMAGE' \
    "${TASK_JSON}" > "${TASK_NEW_JSON}"

NEW_TASK_ARN="$(aws ecs register-task-definition \
    --region "${AWS_REGION}" \
    --cli-input-json "file://${TASK_NEW_JSON}" \
    --query 'taskDefinition.taskDefinitionArn' \
    --output text)"

aws ecs update-service \
    --cluster "${ECS_CLUSTER}" \
    --service "${SERVICE_NAME}" \
    --task-definition "${NEW_TASK_ARN}" \
    --region "${AWS_REGION}" > /dev/null

echo "Service ${SERVICE_NAME} updated to ${NEW_TASK_ARN}"
