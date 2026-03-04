#!/bin/bash
set -e

echo "=== Testing Pipeline with Vulnerable Dependency ==="
echo ""

# Backup original files
cp backend/package.json backend/package.json.backup
cp backend/package-lock.json backend/package-lock.json.backup 2>/dev/null || true

# Add vulnerable dependency with EXACT version pin (no caret)
# lodash 4.17.15 has:
#   - CVE-2021-23337 (HIGH) - Command Injection via template()
#   - CVE-2020-28500 (MEDIUM) - ReDoS in trim functions
echo "Adding lodash@4.17.15 (exact pin, no caret)..."
cd backend
npm install lodash@4.17.15 --save-exact
cd ..

# Verify the pin is exact (no ^ or ~)
if grep -q '"lodash": "4.17.15"' backend/package.json; then
    echo "SUCCESS: Vulnerable dependency pinned exactly to 4.17.15"
else
    echo "WARNING: Version may have caret prefix — fixing..."
    sed -i 's/"lodash": "\^4.17.15"/"lodash": "4.17.15"/' backend/package.json
fi

echo ""
echo "=== Next Steps ==="
echo "1. git add backend/package.json backend/package-lock.json"
echo "2. git commit -m 'test: inject vulnerable lodash for security gate test'"
echo "3. git push origin main"
echo ""
echo "Expected: Pipeline should FAIL at 'SCA Scan' stage (Snyk --severity-threshold=high)"
echo "          CVE-2021-23337 (HIGH) will trigger the gate"
echo ""
echo "=== To Restore (after test) ==="
echo "  mv backend/package.json.backup backend/package.json"
echo "  mv backend/package-lock.json.backup backend/package-lock.json"
echo "  git add backend/package.json backend/package-lock.json"
echo "  git commit -m 'fix: remove vulnerable lodash dependency'"
echo "  git push origin main"
