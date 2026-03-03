#!/bin/bash

JENKINS_IP="34.244.21.72"

echo "Checking Jenkins status..."
echo ""

for i in {1..60}; do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://$JENKINS_IP:8080 2>/dev/null)
    
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "403" ]; then
        echo "✓ Jenkins is UP!"
        echo ""
        echo "Getting admin password..."
        PASSWORD=$(aws ssm get-parameter --region eu-west-1 --name "/taskflow/jenkins-admin-password" --with-decryption --query 'Parameter.Value' --output text 2>/dev/null)
        
        if [ -n "$PASSWORD" ]; then
            echo ""
            echo "=========================================="
            echo "Jenkins Ready!"
            echo "=========================================="
            echo "URL: http://$JENKINS_IP:8080"
            echo "Username: admin"
            echo "Password: $PASSWORD"
            echo ""
            echo "All credentials configured via JCasC!"
            echo "Pipeline job 'taskflow-pipeline' created automatically."
        else
            echo "Password not in SSM yet, checking instance..."
            ssh -i ~/.ssh/id_rsa ec2-user@$JENKINS_IP "sudo cat /var/lib/jenkins/secrets/admin_password 2>/dev/null" || echo "Still configuring..."
        fi
        exit 0
    fi
    
    echo "Waiting... ($i/60)"
    sleep 5
done

echo "Timeout waiting for Jenkins"
