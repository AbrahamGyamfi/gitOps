#!/bin/bash
set -e

PROJECT_KEY="${1:-taskflow}"
SOURCE_DIR="${2:-.}"
ORGANIZATION="${SONAR_ORGANIZATION}"

echo "=== Running SonarCloud SAST Scan ==="
echo "Project: $PROJECT_KEY"
echo "Organization: $ORGANIZATION"
echo "Source: $SOURCE_DIR"

# Validate token exists
if [ -z "$SONAR_TOKEN" ]; then
    echo "ERROR: SONAR_TOKEN is not set"
    exit 1
fi

if [ -z "$ORGANIZATION" ]; then
    echo "ERROR: SONAR_ORGANIZATION is not set"
    exit 1
fi

# Run SonarCloud scanner
docker run --rm \
  -e SONAR_HOST_URL="https://sonarcloud.io" \
  -e SONAR_TOKEN="${SONAR_TOKEN}" \
  -v "$(pwd)/$SOURCE_DIR:/usr/src" \
  sonarsource/sonar-scanner-cli:latest \
  -Dsonar.projectKey="$PROJECT_KEY" \
  -Dsonar.organization="$ORGANIZATION" \
  -Dsonar.sources=. \
  -Dsonar.exclusions="**/node_modules/**,**/test/**,**/tests/**"

echo "SUCCESS: SonarCloud scan completed"
