#!/bin/bash

IMAGE=$1
REPORT_FILE=${2:-sbom.json}

echo "📦 Generating SBOM for: $IMAGE"

# Install Syft locally if not present
if ! command -v syft &> /dev/null && [ ! -f ./syft ]; then
    echo "Installing Syft..."
    curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b .
fi

# Use local or system syft
if [ -f ./syft ]; then
    SYFT_BIN=./syft
else
    SYFT_BIN=syft
fi

# Generate SBOM
$SYFT_BIN $IMAGE -o json > $REPORT_FILE

echo "✅ SBOM generated: $REPORT_FILE"
