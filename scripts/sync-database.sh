#!/bin/bash
# sync-database.sh - Sync Amazon Q Developer CLI database with S3

set -e

# Database location
Q_DATABASE_DIR="$HOME/.local/share/amazon-q"
Q_DATABASE_FILE="$Q_DATABASE_DIR/data.sqlite3"

# Function to download database from S3
download_database() {
    if [ -z "$Q_DATABASE_S3_URI" ]; then
        echo "Q_DATABASE_S3_URI environment variable not set. Skipping database download."
        return 0
    fi

    echo "Checking for existing database in S3: $Q_DATABASE_S3_URI"
    
    # Check if the database exists in S3
    if aws s3 ls "$Q_DATABASE_S3_URI" &>/dev/null; then
        echo "Database found in S3. Downloading..."
        
        # Create directory if it doesn't exist
        mkdir -p "$Q_DATABASE_DIR"
        
        # Download the database
        aws s3 cp "$Q_DATABASE_S3_URI" "$Q_DATABASE_FILE"
        
        echo "Database downloaded successfully."
    else
        echo "No existing database found in S3. Will create a new one."
    fi
}

# Function to upload database to S3
upload_database() {
    if [ -z "$Q_DATABASE_S3_URI" ]; then
        echo "Q_DATABASE_S3_URI environment variable not set. Skipping database upload."
        return 0
    fi

    if [ -f "$Q_DATABASE_FILE" ]; then
        echo "Uploading database to S3: $Q_DATABASE_S3_URI"
        aws s3 cp "$Q_DATABASE_FILE" "$Q_DATABASE_S3_URI"
        echo "Database uploaded successfully."
    else
        echo "No database file found at $Q_DATABASE_FILE. Nothing to upload."
    fi
}

# Main execution
case "$1" in
    download)
        download_database
        ;;
    upload)
        upload_database
        ;;
    *)
        echo "Usage: $0 {download|upload}"
        echo "  download: Download database from S3"
        echo "  upload: Upload database to S3"
        exit 1
        ;;
esac

exit 0
