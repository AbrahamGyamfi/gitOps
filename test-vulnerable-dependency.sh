#!/bin/bash
# Test Script: Inject Vulnerable Dependency and Verify Pipeline Blocks

echo "=== Testing Pipeline Security Gates ==="
echo ""

# Step 1: Inject vulnerable dependency
echo "Step 1: Injecting vulnerable dependency (lodash@4.17.15 - CVE-2020-8203)"
cd backend
cp package.json package.json.backup

# Add vulnerable lodash version
jq '.dependencies.lodash = "4.17.15"' package.json > package.json.tmp && mv package.json.tmp package.json

echo "✅ Vulnerable dependency added to backend/package.json"
echo ""

# Step 2: Commit and push
echo "Step 2: Committing vulnerable dependency..."
git add package.json
git commit -m "test: inject vulnerable dependency for testing"
git push

echo "✅ Changes pushed to repository"
echo ""

# Step 3: Monitor Jenkins build
echo "Step 3: Monitor Jenkins build - it should FAIL at SCA stage"
echo "Expected: Pipeline blocks with CRITICAL vulnerability detected"
echo ""
echo "Jenkins URL: http://34.254.178.139:8080"
echo ""
echo "Press ENTER after build fails..."
read

# Step 4: Fix vulnerability
echo "Step 4: Fixing vulnerability by removing lodash..."
mv package.json.backup package.json

git add package.json
git commit -m "fix: remove vulnerable dependency"
git push

echo "✅ Vulnerability fixed and pushed"
echo ""

# Step 5: Monitor Jenkins build again
echo "Step 5: Monitor Jenkins build - it should SUCCEED now"
echo "Expected: Pipeline passes all security gates"
echo ""
echo "Test complete! Verify:"
echo "1. First build FAILED at SCA stage"
echo "2. Second build PASSED all stages"
