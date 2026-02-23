#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="${1:?Usage: sca-scan.sh <project-name> <source-dir> [report-subdir]}"
SOURCE_DIR="${2:?Usage: sca-scan.sh <project-name> <source-dir> [report-subdir]}"
REPORT_SUBDIR="${3:-${PROJECT_NAME}}"

: "${WORKSPACE:=$(pwd)}"
: "${SCAN_REPORTS_DIR:=security-reports}"
: "${OWASP_DC_IMAGE:=owasp/dependency-check:latest}"

REPORT_DIR="${WORKSPACE}/${SCAN_REPORTS_DIR}/${REPORT_SUBDIR}"
REPORT_FILE="${REPORT_DIR}/dependency-check-report.json"
SOURCE_PATH="${WORKSPACE}/${SOURCE_DIR}"

mkdir -p "${REPORT_DIR}"

echo "Running SCA for ${PROJECT_NAME}..."
docker run --rm \
    -v "${SOURCE_PATH}:/src" \
    -v "${REPORT_DIR}:/report" \
    -v "${HOME}/.m2:/root/.m2" \
    "${OWASP_DC_IMAGE}" \
    --scan /src \
    --format JSON \
    --out /report \
    --project "${PROJECT_NAME}" \
    --enableExperimental

if [ ! -f "${REPORT_FILE}" ]; then
    echo "Dependency-Check report not generated for ${PROJECT_NAME}"
    exit 1
fi

CRITICAL="$(jq '[.dependencies[]?.vulnerabilities[]? | select(.severity=="CRITICAL")] | length' "${REPORT_FILE}")"
HIGH="$(jq '[.dependencies[]?.vulnerabilities[]? | select(.severity=="HIGH")] | length' "${REPORT_FILE}")"

echo "${PROJECT_NAME} vulnerabilities - Critical: ${CRITICAL}, High: ${HIGH}"

if [ "${CRITICAL}" -gt 0 ] || [ "${HIGH}" -gt 0 ]; then
    echo "Vulnerabilities found in ${PROJECT_NAME} dependencies"
    exit 1
fi
