#!/bin/bash
# Script to test security scanning by injecting vulnerable dependency

echo "🧪 Testing Security Pipeline - Injecting Vulnerable Dependency"

# Backup original package.json
cp backend/package.json backend/package.json.backup

# Add vulnerable version of express (known CVE)
cat > backend/package.json << 'EOF'
{
  "name": "taskflow-backend",
  "version": "1.0.0",
  "description": "TaskFlow backend API",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "test": "jest --coverage"
  },
  "dependencies": {
    "express": "4.16.0",
    "cors": "^2.8.5",
    "uuid": "^9.0.0"
  },
  "devDependencies": {
    "jest": "^29.5.0",
    "supertest": "^6.3.3"
  }
}
EOF

echo "✅ Injected vulnerable express@4.16.0 (has known CVEs)"
echo "📝 Original package.json backed up to package.json.backup"
echo ""
echo "To restore:"
echo "  mv backend/package.json.backup backend/package.json"
