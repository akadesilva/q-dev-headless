#!/bin/bash
# q-authenticate.sh - Handle Amazon Q Developer CLI authentication

set -e

# Check if we're already authenticated by checking if the token exists
# This is a simplified check - you might need to verify the token is valid
if q whoami &>/dev/null; then
    echo "Already authenticated with Amazon Q Developer CLI"
    exit 0
fi

# Get credentials from environment variables or AWS Secrets Manager
if [ -z "$SSO_URL" ] || [ -z "$REGION" ]; then
    echo "Fetching credentials from AWS Secrets Manager..."
    # Use the environment variable for the secret ID if provided
    SECRET_ID=${AMAZON_Q_CREDENTIALS_SECRET_ID:-"amazon-q-headless/amazon-q-credentials"}
    SECRETS=$(aws secretsmanager get-secret-value --secret-id "$SECRET_ID" --query SecretString --output text 2>/dev/null || echo "{}")
    SSO_URL=${SSO_URL:-$(echo $SECRETS | jq -r '.sso_url // ""')}
    REGION=${REGION:-$(echo $SECRETS | jq -r '.region // ""')}
fi

if [ -z "$SSO_URL" ] || [ -z "$REGION" ]; then
    echo "Error: SSO_URL and REGION must be provided via environment variables or Secrets Manager"
    exit 1
fi

# Use expect script to get authentication URL and code
echo "Starting Amazon Q Developer CLI authentication process..."
AUTH_OUTPUT=$(/usr/local/bin/expect-login.sh "$SSO_URL" "$REGION")
echo $AUTH_OUTPUT
AUTH_URL=$(echo "$AUTH_OUTPUT" | grep "Authentication URL:" | awk '{print $3}')

if [ -z "$AUTH_URL" ]; then
    echo "Error: Failed to get authentication URL and code"
    echo "Output: $AUTH_OUTPUT"
    exit 1
fi

exit 0
