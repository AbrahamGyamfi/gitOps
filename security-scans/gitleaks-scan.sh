#!/bin/bash

REPORT_FILE=${1:-gitleaks-report.json}

echo "🔍 Scanning for secrets..."

# Install Gitleaks if not present
if ! command -v gitleaks &> /dev/null; then
    echo "Installing Gitleaks..."
    wget -qO gitleaks.tar.gz https://github.com/gitleaks/gitleaks/releases/download/v8.18.0/gitleaks_8.18.0_linux_x64.tar.gz
    tar -xzf gitleaks.tar.gz gitleaks
    chmod +x gitleaks
    rm gitleaks.tar.gz
    GITLEAKS_BIN=./gitleaks
else
    GITLEAKS_BIN=gitleaks
fi

# Scan repository
$GITLEAKS_BIN detect --report-format json --report-path $REPORT_FILE --no-git || true

# Check for secrets
if [ -f "$REPORT_FILE" ]; then
    SECRETS=$(jq '. | length' $REPORT_FILE)
    echo "📊 Found $SECRETS potential secrets"
    
    if [ "$SECRETS" -gt 0 ]; then
        echo "❌ FAILED: Secrets detected in code"
        jq -r '.[] | "  - \(.Description) in \(.File):\(.StartLine)"' $REPORT_FILE
        exit 1
    fi
fi

echo "✅ PASSED: No secrets detected"
