#!/bin/bash
# entrypoint.sh - Main entrypoint for the Amazon Q Developer CLI container

set -e

# Download database from S3 if available
if [ -n "$Q_DATABASE_S3_URI" ]; then
    echo "Syncing database from S3..."
    /usr/local/bin/sync-database.sh download
fi

# Set up trap to upload database to S3 on exit
if [ -n "$Q_DATABASE_S3_URI" ]; then
    trap '/usr/local/bin/sync-database.sh upload' EXIT
fi

# Check if we need to authenticate
if ! q whoami &>/dev/null; then
    echo "Amazon Q Developer CLI authentication required"
    
    # Check if we should skip authentication (for testing)
    if [ "$SKIP_AUTH" = "true" ]; then
        echo "Authentication check skipped due to SKIP_AUTH=true"
    else
        # Run authentication script
        /usr/local/bin/q-authenticate.sh
        
        # If authentication script exits with code 1, authentication failed
        if [ $? -eq 1 ]; then
            echo "Authentication failed or timedout"
            exit 0
        fi
    fi
fi

# Check if we should process requirements
if [ "$PROCESS_REQUIREMENTS" = "true" ]; then
    echo "Processing requirements..."
    /usr/local/bin/q-process-requirements.sh
    exit $?
fi

# If no specific action is requested, show help
if [ $# -eq 0 ]; then
    echo "Amazon Q Developer CLI Container"
    echo ""
    echo "Available commands:"
    echo "  - authenticate: Run the authentication process"
    echo "  - process: Process requirements using Amazon Q"
    echo ""
    echo "Environment variables:"
    echo "  - SKIP_AUTH: Set to 'true' to skip authentication check"
    echo "  - PROCESS_REQUIREMENTS: Set to 'true' to process requirements"
    echo "  - REPO_URL: URL of the Git repository to clone"
    echo "  - INSTRUCTIONS_S3_URI: S3 URI of the instructions file"
    echo "  - BRANCH_NAME: Git branch name for implementation"
    echo "  - COMMIT_MESSAGE: Git commit message"
    echo "  - Q_DATABASE_S3_URI: S3 URI for storing/retrieving the Q CLI database"
    echo "  - GIT_CREDENTIALS_SECRET_ID: Secret ID for Git credentials in AWS Secrets Manager"
    echo "  - AMAZON_Q_CREDENTIALS_SECRET_ID: Secret ID for Amazon Q credentials in AWS Secrets Manager"
    echo ""
    exit 0
fi

# Handle specific commands
case "$1" in
    authenticate)
        /usr/local/bin/q-authenticate.sh
        ;;
    process)
        /usr/local/bin/q-process-requirements.sh
        ;;
    *)
        # Pass through to q cli
        q "$@"
        ;;
esac
