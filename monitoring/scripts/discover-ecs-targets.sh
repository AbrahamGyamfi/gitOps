#!/bin/bash
# Discovers ECS Fargate task IPs via Cloud Map (Service Discovery) DNS
# and writes Prometheus file_sd targets JSON.
# Run via cron every 30s on the monitoring server.

set -euo pipefail

TARGETS_DIR="/home/ec2-user/monitoring/targets"
TARGETS_FILE="${TARGETS_DIR}/taskflow-backend.json"
SERVICE_DNS="taskflow-backend.taskflow.local"
PORT=5000

mkdir -p "$TARGETS_DIR"

# Resolve Cloud Map DNS to get current ECS task IPs
TASK_IPS=$(dig +short "$SERVICE_DNS" 2>/dev/null | grep -E '^[0-9]+\.' || true)

if [ -z "$TASK_IPS" ]; then
    echo "[]" > "$TARGETS_FILE"
    echo "$(date -Iseconds) WARNING: No task IPs found for $SERVICE_DNS"
    exit 0
fi

# Build Prometheus file_sd JSON
TARGETS=""
for IP in $TASK_IPS; do
    if [ -n "$TARGETS" ]; then
        TARGETS="${TARGETS},"
    fi
    TARGETS="${TARGETS}\"${IP}:${PORT}\""
done

cat > "$TARGETS_FILE" <<EOF
[
  {
    "targets": [${TARGETS}],
    "labels": {
      "job": "taskflow-backend",
      "service": "taskflow-backend",
      "environment": "production"
    }
  }
]
EOF

echo "$(date -Iseconds) Updated targets: [${TARGETS}]"
