#!/usr/bin/env bash
set -euo pipefail

: "${WORKSPACE:=$(pwd)}"
: "${SCAN_REPORTS_DIR:=security-reports}"
: "${GITLEAKS_IMAGE:=zricethezav/gitleaks:latest}"

mkdir -p "${WORKSPACE}/${SCAN_REPORTS_DIR}"

echo "Running secret scan with Gitleaks..."
docker run --rm -v "${WORKSPACE}:/repo" "${GITLEAKS_IMAGE}" \
    detect \
    --source /repo \
    --report-format json \
    --report-path "/repo/${SCAN_REPORTS_DIR}/gitleaks-report.json" \
    --no-git \
    --redact \
    --exit-code 1
