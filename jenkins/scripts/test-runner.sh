#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:?Usage: test-runner.sh <backend|frontend>}"

: "${WORKSPACE:=$(pwd)}"
: "${NODE_TEST_IMAGE:=node:18-alpine}"

case "${TARGET}" in
    backend)
        APP_DIR="${WORKSPACE}/backend"
        TEST_CMD='npm ci && npm test -- --coverage'
        ;;
    frontend)
        APP_DIR="${WORKSPACE}/frontend"
        TEST_CMD='npm ci --legacy-peer-deps && CI=true npm test -- --coverage'
        ;;
    *)
        echo "Invalid target: ${TARGET}. Use backend or frontend."
        exit 1
        ;;
esac

echo "Running ${TARGET} tests..."
docker run --rm -v "${APP_DIR}:/app" -w /app "${NODE_TEST_IMAGE}" sh -c "${TEST_CMD}"
