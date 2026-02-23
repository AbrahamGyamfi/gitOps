#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="${1:?Usage: container-scan.sh <image-name> <image-tag> [report-key]}"
IMAGE_TAG="${2:?Usage: container-scan.sh <image-name> <image-tag> [report-key]}"
REPORT_KEY="${3:-$(basename "${IMAGE_NAME}")}"

: "${WORKSPACE:=$(pwd)}"
: "${SCAN_REPORTS_DIR:=security-reports}"
: "${TRIVY_IMAGE:=aquasec/trivy:latest}"

mkdir -p "${WORKSPACE}/${SCAN_REPORTS_DIR}"
REPORT_FILE="${WORKSPACE}/${SCAN_REPORTS_DIR}/trivy-${REPORT_KEY}.json"

echo "Running container scan for ${IMAGE_NAME}:${IMAGE_TAG}..."
docker run --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v trivy-cache:/root/.cache/trivy \
    "${TRIVY_IMAGE}" image \
    --severity HIGH,CRITICAL \
    --format json \
    --timeout 10m \
    "${IMAGE_NAME}:${IMAGE_TAG}" > "${REPORT_FILE}"

CRITICAL="$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="CRITICAL")] | length' "${REPORT_FILE}")"
HIGH="$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="HIGH")] | length' "${REPORT_FILE}")"

echo "Container vulnerabilities - Critical: ${CRITICAL}, High: ${HIGH}"

if [ "${CRITICAL}" -gt 0 ] || [ "${HIGH}" -gt 0 ]; then
    echo "Vulnerabilities found in ${IMAGE_NAME}:${IMAGE_TAG}"
    exit 1
fi
