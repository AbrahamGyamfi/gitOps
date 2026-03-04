#!/bin/bash
set -e

DIR=$1

echo "=== Running SCA Security Scan ==="
echo "Directory: $DIR"

# ── Step 1: npm audit (no external token needed - always works) ──
echo ""
echo "--- npm audit (built-in vulnerability check) ---"
docker run --rm \
    -v $(pwd)/$DIR:/project \
    -w /project \
    node:18-alpine \
    sh -c 'npm audit --audit-level=high; exit $?'

echo "npm audit passed - no High/Critical vulnerabilities"

# ── Step 2: Snyk deep scan (requires SNYK_TOKEN) ──
echo ""
echo "--- Snyk SCA (deep dependency analysis) ---"
if [ -z "${SNYK_TOKEN}" ]; then
    echo "WARNING: SNYK_TOKEN not set - skipping Snyk scan (npm audit already passed)"
else
    # Override entrypoint - the default snyk/snyk:node entrypoint silently swallows exit codes
    docker run --rm \
        --entrypoint="" \
        -e SNYK_TOKEN="${SNYK_TOKEN}" \
        -v $(pwd)/$DIR:/project \
        -w /project \
        snyk/snyk:node \
        sh -c 'snyk test --severity-threshold=high; exit $?'

    echo "Snyk scan passed - no High/Critical vulnerabilities"

    # Generate JSON report (|| true so report generation doesn't block pipeline)
    docker run --rm \
        --entrypoint="" \
        -e SNYK_TOKEN="${SNYK_TOKEN}" \
        -v $(pwd)/$DIR:/project \
        -w /project \
        snyk/snyk:node \
        sh -c 'snyk test --json' > snyk-$DIR-report.json || true
fi

echo "SUCCESS: SCA scan completed for $DIR"
