README.md
# SBOM Files

SBOM (Software Bill of Materials) files are generated using Syft during each pipeline execution.

## Access Location
Jenkins Build Artifacts → security-reports/ → backend-sbom.json, frontend-sbom.json

## Format
CycloneDX JSON

## Contents
- All application dependencies
- Package versions
- License information
- Component relationships
- Vulnerability references
