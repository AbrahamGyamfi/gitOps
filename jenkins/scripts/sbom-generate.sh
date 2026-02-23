#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="${1:?Usage: sbom-generate.sh <image-name> <image-tag> [report-key]}"
IMAGE_TAG="${2:?Usage: sbom-generate.sh <image-name> <image-tag> [report-key]}"
REPORT_KEY="${3:-$(basename "${IMAGE_NAME}")}"

: "${WORKSPACE:=$(pwd)}"
: "${SCAN_REPORTS_DIR:=security-reports}"
: "${SYFT_IMAGE:=anchore/syft:latest}"

mkdir -p "${WORKSPACE}/${SCAN_REPORTS_DIR}"
REPORT_FILE="${WORKSPACE}/${SCAN_REPORTS_DIR}/sbom-${REPORT_KEY}.json"

echo "Generating SBOM for ${IMAGE_NAME}:${IMAGE_TAG}..."
docker run --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    "${SYFT_IMAGE}" \
    "${IMAGE_NAME}:${IMAGE_TAG}" \
    -o cyclonedx-json > "${REPORT_FILE}"
