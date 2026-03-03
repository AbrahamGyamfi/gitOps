#!/bin/bash
set -e

DIR=$1

echo "=== Running Snyk SCA ==="
echo "Directory: $DIR"

# Run Snyk test via Docker - fail on high severity
docker run --rm \
    -e SNYK_TOKEN="${SNYK_TOKEN}" \
    -v $(pwd)/$DIR:/project \
    -w /project \
    snyk/snyk:node \
    test --severity-threshold=high

# Also generate JSON report
docker run --rm \
    -e SNYK_TOKEN="${SNYK_TOKEN}" \
    -v $(pwd)/$DIR:/project \
    -w /project \
    snyk/snyk:node \
    test --json > snyk-$DIR-report.json || true

echo "✅ Snyk scan completed - Pipeline will FAIL if High/Critical vulnerabilities found"
