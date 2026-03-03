#!/bin/bash

IMAGE=$1
REPORT_FILE=${2:-trivy-report.json}

echo "🔍 Scanning image: $IMAGE"

# Use Trivy via Docker (no installation needed) - exit on error
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
    -v $(pwd):/output \
    aquasec/trivy:latest image \
    --format json \
    --output /output/$REPORT_FILE \
    --severity CRITICAL,HIGH \
    --exit-code 1 \
    $IMAGE

echo "Trivy scan PASSED - No Critical/High vulnerabilities found"
