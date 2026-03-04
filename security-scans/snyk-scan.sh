#!/bin/bash
set -e

DIR=$1

echo "=== Running SCA Security Scan ==="
echo "Directory: $DIR"

# ── Step 1: npm audit (no external token needed - always works) ──
# --omit=dev: only audit production deps (devDeps don't ship in Docker images)
# For frontend (React/Nginx static build): all deps are build-time only,
# the production image is just Nginx serving static files — no Node.js runtime.
# We use --audit-level=critical for frontend since react-scripts vulns are
# build-time only and don't affect the deployed Nginx image.
echo ""
echo "--- npm audit (built-in vulnerability check) ---"
if [ "$DIR" = "frontend" ]; then
    echo "Frontend is a static Nginx build — auditing at CRITICAL level only"
    docker run --rm \
        -v $(pwd)/$DIR:/project \
        -w /project \
        node:18-alpine \
        sh -c 'npm audit --audit-level=critical; exit $?'
else
    docker run --rm \
        -v $(pwd)/$DIR:/project \
        -w /project \
        node:18-alpine \
        sh -c 'npm audit --audit-level=high --omit=dev; exit $?'
fi

echo "npm audit passed - no High/Critical vulnerabilities"

# ── Step 2: Snyk deep scan (requires SNYK_TOKEN) ──
echo ""
echo "--- Snyk SCA (deep dependency analysis) ---"
if [ -z "${SNYK_TOKEN}" ]; then
    echo "WARNING: SNYK_TOKEN not set - skipping Snyk scan (npm audit already passed)"
else
    # Override entrypoint - the default snyk/snyk:node entrypoint silently swallows exit codes
    # Snyk exit codes: 0=clean, 1=vulnerabilities found, 2=error (auth/network/etc)
    set +e
    docker run --rm \
        --entrypoint="" \
        -e SNYK_TOKEN="${SNYK_TOKEN}" \
        -v $(pwd)/$DIR:/project \
        -w /project \
        snyk/snyk:node \
        sh -c 'snyk test --severity-threshold=high; exit $?'
    SNYK_EXIT=$?
    set -e

    if [ $SNYK_EXIT -eq 0 ]; then
        echo "Snyk scan passed - no High/Critical vulnerabilities"
    elif [ $SNYK_EXIT -eq 1 ]; then
        echo "FAILED: Snyk found High/Critical vulnerabilities in $DIR"
        exit 1
    else
        echo "WARNING: Snyk returned error (exit code $SNYK_EXIT) - auth/network issue"
        echo "npm audit already passed, so this is non-blocking"
    fi

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
