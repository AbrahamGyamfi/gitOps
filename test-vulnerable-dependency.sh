#!/bin/bash

echo "=== Testing Pipeline with Vulnerable Dependency ==="

# Backup original package.json
cp backend/package.json backend/package.json.backup

# Add vulnerable dependency (lodash 4.17.15 has known vulnerabilities)
echo "Adding vulnerable lodash version..."
cd backend
npm install lodash@4.17.15 --save
cd ..

echo "✅ Vulnerable dependency added"
echo "📝 Commit and push to trigger pipeline"
echo ""
echo "Expected: Pipeline should FAIL at SCA Scan stage"
echo ""
echo "To restore:"
echo "  mv backend/package.json.backup backend/package.json"
echo "  cd backend && npm install"
