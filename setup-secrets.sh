#!/bin/bash
set -e

# Check if AWS region is provided
AWS_REGION=${1:-"us-east-1"}

echo "Setting up secrets in AWS Secrets Manager..."

# Create Git credentials secret
echo "Creating Git credentials secret..."
cat > git-credentials.json << EOF
{
  "token": "your-github-personal-access-token",
  "email": "your-email@example.com"
}
EOF

aws secretsmanager create-secret \
  --name amazon-q-headless/git-credentials \
  --description "Git credentials for Amazon Q Headless" \
  --secret-string file://git-credentials.json \
  --region $AWS_REGION || \
aws secretsmanager update-secret \
  --secret-id amazon-q-headless/git-credentials \
  --secret-string file://git-credentials.json \
  --region $AWS_REGION

# Create Amazon Q credentials secret
echo "Creating Amazon Q credentials secret..."
cat > amazon-q-credentials.json << EOF
{
  "sso_url": "https://view.awsapps.com/start",
  "region": "us-east-1"
}
EOF

aws secretsmanager create-secret \
  --name amazon-q-headless/amazon-q-credentials \
  --description "Amazon Q credentials for Amazon Q Headless" \
  --secret-string file://amazon-q-credentials.json \
  --region $AWS_REGION || \
aws secretsmanager update-secret \
  --secret-id amazon-q-headless/amazon-q-credentials \
  --secret-string file://amazon-q-credentials.json \
  --region $AWS_REGION

# Clean up temporary files
rm -f git-credentials.json amazon-q-credentials.json

echo "Secrets created successfully!"
echo "IMPORTANT: Please update the secret values with your actual credentials using the AWS Management Console or AWS CLI."
echo "Git Credentials Secret ID: amazon-q-headless/git-credentials"
echo "Amazon Q Credentials Secret ID: amazon-q-headless/amazon-q-credentials"
