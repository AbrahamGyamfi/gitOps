#!/bin/bash
set -e

JENKINS_URL="http://34.247.53.251:8080"
JENKINS_USER="admin"
JENKINS_PASSWORD=$(aws ssm get-parameter --name /taskflow/jenkins-admin-password --with-decryption --query 'Parameter.Value' --output text)

# Get SonarQube token
echo "=== Getting SonarQube Token ==="
SONAR_TOKEN=$(curl -s -u admin:admin -X POST "http://34.247.53.251:9000/api/user_tokens/generate?name=jenkins" | jq -r '.token')
echo "SonarQube Token: $SONAR_TOKEN"

# Get Jenkins crumb for CSRF protection
CRUMB=$(curl -s -u "$JENKINS_USER:$JENKINS_PASSWORD" "$JENKINS_URL/crumbIssuer/api/json" | jq -r '.crumb')

# Add sonar-token credential
echo "=== Adding sonar-token credential ==="
curl -s -u "$JENKINS_USER:$JENKINS_PASSWORD" \
  -H "Jenkins-Crumb: $CRUMB" \
  -X POST "$JENKINS_URL/credentials/store/system/domain/_/createCredentials" \
  --data-urlencode 'json={
    "": "0",
    "credentials": {
      "scope": "GLOBAL",
      "id": "sonar-token",
      "secret": "'$SONAR_TOKEN'",
      "description": "SonarQube Authentication Token",
      "$class": "org.jenkinsci.plugins.plaincredentials.impl.StringCredentialsImpl"
    }
  }'

# Add sonar-host-url credential
echo "=== Adding sonar-host-url credential ==="
curl -s -u "$JENKINS_USER:$JENKINS_PASSWORD" \
  -H "Jenkins-Crumb: $CRUMB" \
  -X POST "$JENKINS_URL/credentials/store/system/domain/_/createCredentials" \
  --data-urlencode 'json={
    "": "0",
    "credentials": {
      "scope": "GLOBAL",
      "id": "sonar-host-url",
      "secret": "http://localhost:9000",
      "description": "SonarQube Host URL",
      "$class": "org.jenkinsci.plugins.plaincredentials.impl.StringCredentialsImpl"
    }
  }'

# Add snyk-token credential (placeholder - user needs to update)
echo "=== Adding snyk-token credential (placeholder) ==="
curl -s -u "$JENKINS_USER:$JENKINS_PASSWORD" \
  -H "Jenkins-Crumb: $CRUMB" \
  -X POST "$JENKINS_URL/credentials/store/system/domain/_/createCredentials" \
  --data-urlencode 'json={
    "": "0",
    "credentials": {
      "scope": "GLOBAL",
      "id": "snyk-token",
      "secret": "PLACEHOLDER_UPDATE_WITH_REAL_TOKEN",
      "description": "Snyk API Token - Update at https://snyk.io/account",
      "$class": "org.jenkinsci.plugins.plaincredentials.impl.StringCredentialsImpl"
    }
  }'

echo ""
echo "✅ Credentials added to Jenkins!"
echo ""
echo "Next steps:"
echo "1. Get Snyk token from https://snyk.io/account"
echo "2. Update snyk-token credential in Jenkins UI"
echo "3. Or run: snyk auth (on Jenkins server)"
