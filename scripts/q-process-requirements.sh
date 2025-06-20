#!/bin/bash
# q-process-requirements.sh - Process requirements using Amazon Q Developer CLI

set -e

echo "Starting Amazon Q Developer CLI requirements processing..."

# Required environment variables
if [ -z "$REPO_URL" ]; then
    echo "Error: REPO_URL environment variable is required"
    exit 1
fi

if [ -z "$INSTRUCTIONS_S3_URI" ]; then
    echo "Error: INSTRUCTIONS_S3_URI environment variable is required"
    exit 1
fi

# Optional environment variables with defaults
BRANCH_NAME=${BRANCH_NAME:-"feature/q-implementation-$(date +%Y%m%d-%H%M%S)"}
COMMIT_MESSAGE=${COMMIT_MESSAGE:-"Implement requirements using Amazon Q Developer"}
GIT_EMAIL=${GIT_EMAIL:-"amazon-q-bot@example.com"}
GIT_NAME=${GIT_NAME:-"Amazon Q Bot"}
WORKSPACE_DIR=${WORKSPACE_DIR:-"/workspace"}
OUTPUT_FILE=${OUTPUT_FILE:-"q-implementation.md"}

# Get Git credentials from AWS Secrets Manager
echo "Fetching Git credentials from AWS Secrets Manager..."
# Use the environment variable for the secret ID if provided
GIT_SECRET_ID=${GIT_CREDENTIALS_SECRET_ID:-"amazon-q-headless/git-credentials"}
GIT_SECRETS=$(aws secretsmanager get-secret-value --secret-id "$GIT_SECRET_ID" --query SecretString --output text 2>/dev/null || echo "{}")
GIT_TOKEN=$(echo $GIT_SECRETS | jq -r '.token // ""')
GIT_EMAIL=$(echo $GIT_SECRETS | jq -r '.email // "amazon-q-bot@example.com"')

if [ -z "$GIT_TOKEN" ]; then
    echo "Warning: No Git token found in Secrets Manager"
fi

# Configure git
git config --global user.email "$GIT_EMAIL"
git config --global user.name "$GIT_NAME"

# Set up Git credentials if provided
if [ -n "$GIT_TOKEN" ]; then
    echo "Setting up Git credentials with personal access token..."
    git config --global credential.helper store
    
    # Extract domain from repo URL
    if [[ "$REPO_URL" =~ https://([^/]+) ]]; then
        DOMAIN="${BASH_REMATCH[1]}"
        echo "https://$GIT_TOKEN:x-oauth-basic@$DOMAIN" > ~/.git-credentials
    else
        echo "https://$GIT_TOKEN:x-oauth-basic@github.com" > ~/.git-credentials
    fi
    
    chmod 600 ~/.git-credentials
fi

# Create workspace directory if it doesn't exist
mkdir -p "$WORKSPACE_DIR"
cd "$WORKSPACE_DIR"

# Clone the repository
echo "Cloning repository: $REPO_URL"
git clone "$REPO_URL" repo
cd repo

# Use existing branch or create a new one
if git show-ref --verify --quiet "refs/remotes/origin/$BRANCH_NAME"; then
    echo "Checking out existing branch: $BRANCH_NAME"
    git checkout $BRANCH_NAME
    git pull origin $BRANCH_NAME
else
    echo "Creating new branch: $BRANCH_NAME"
    git checkout -b "$BRANCH_NAME"
fi

# Create a temporary directory for instructions
INSTRUCTIONS_DIR="/tmp/instructions"
mkdir -p "$INSTRUCTIONS_DIR"

# Download instructions from S3
echo "Downloading instructions from S3: $INSTRUCTIONS_S3_URI"

# Check if the URI ends with a wildcard or is a prefix
if [[ "$INSTRUCTIONS_S3_URI" == *"*" ]]; then
    # Handle wildcard by using recursive copy
    S3_PREFIX=$(echo "$INSTRUCTIONS_S3_URI" | sed 's/\*$//')
    echo "Detected wildcard pattern. Using S3 prefix: $S3_PREFIX"
    aws s3 cp --recursive "$S3_PREFIX" "$INSTRUCTIONS_DIR/"
else
    # Handle single file
    aws s3 cp "$INSTRUCTIONS_S3_URI" "$INSTRUCTIONS_DIR/instructions.md"
fi

# Check if we have any files
if [ -z "$(ls -A $INSTRUCTIONS_DIR)" ]; then
    echo "Error: No files downloaded from $INSTRUCTIONS_S3_URI"
    exit 1
fi

# Run q chat with the instructions
echo "Processing instructions with Amazon Q Developer..."
pwd
q chat --no-interactive --trust-all-tools "Execute the instructions in /tmp/instructions/instructions.md. The workspace folder is /workspace/repo/. When the task is completed commit with a meaningful, descriptive message and push to repository." > /tmp/q-output.txt

cat /tmp/q-output.txt
