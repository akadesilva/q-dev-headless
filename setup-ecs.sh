#!/bin/bash
set -e

# Get AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
AWS_REGION="us-east-1"

# Create ECS cluster if it doesn't exist
echo "Creating ECS cluster (if it doesn't exist)..."
aws ecs describe-clusters --clusters amazon-q-cluster > /dev/null 2>&1 || \
aws ecs create-cluster --cluster-name amazon-q-cluster

# Create S3 bucket for instructions and database (if needed)
# Use a fixed bucket name or check if an environment variable is set
BUCKET_NAME=${S3_BUCKET_NAME:-"amazon-q-demo-$(date +%s)"}
echo "Using S3 bucket: $BUCKET_NAME"

# Check if bucket exists, create if it doesn't
aws s3api head-bucket --bucket $BUCKET_NAME 2>/dev/null || \
(echo "Creating S3 bucket: $BUCKET_NAME..." && \
aws s3 mb s3://$BUCKET_NAME)

# Create a sample instructions file
echo "Creating sample instructions file..."
cat > dummy_instructions.md << 'EOF'
## Feature Requirements
- Create a simple REST API endpoint that returns the current time
- Add a health check endpoint that returns system status
## End Requirements
EOF

# Upload instructions to S3
echo "Uploading instructions to S3..."
aws s3 cp dummy_instructions.md s3://$BUCKET_NAME/q-headless/dummy_instructions.md

# Create SNS topic for login notifications if it doesn't exist
echo "Creating SNS topic for login notifications (if it doesn't exist)..."
SNS_TOPIC_ARN=$(aws sns list-topics --query "Topics[?contains(TopicArn, 'q-dev-cli-login')].TopicArn" --output text)

if [ -z "$SNS_TOPIC_ARN" ]; then
  echo "Creating new SNS topic..."
  SNS_TOPIC_ARN=$(aws sns create-topic --name q-dev-cli-login --query 'TopicArn' --output text)
else
  echo "Using existing SNS topic: $SNS_TOPIC_ARN"
fi

# Create task definition JSON
echo "Creating task definition..."
cat > amazon-q-task-cli.json << EOF
{
  "family": "amazon-q-task-cli",
  "executionRoleArn": "arn:aws:iam::$AWS_ACCOUNT_ID:role/ecsTaskExecutionRole",
  "taskRoleArn": "arn:aws:iam::$AWS_ACCOUNT_ID:role/AmazonQTaskRole",
  "networkMode": "awsvpc",
  "containerDefinitions": [
    {
      "name": "amazon-q-container",
      "image": "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/amazon-q-dev-cli:latest",
      "essential": true,
      "environment": [
        { "name": "PROCESS_REQUIREMENTS", "value": "true" },
        { "name": "LOGIN_SNS_TOPIC", "value": "$SNS_TOPIC_ARN" },
        { "name": "REPO_URL", "value": "https://github.com/akadesilva/q-headless-demo1" },
        { "name": "INSTRUCTIONS_S3_URI", "value": "s3://$BUCKET_NAME/q-headless/dummy_instructions.md" },
        { "name": "BRANCH_NAME", "value": "main" },
        { "name": "Q_DATABASE_S3_URI", "value": "s3://$BUCKET_NAME/q-headless/database/data.sqlite3" },
        { "name": "GIT_CREDENTIALS_SECRET_ID", "value": "amazon-q-headless/git-credentials" },
        { "name": "AMAZON_Q_CREDENTIALS_SECRET_ID", "value": "amazon-q-headless/amazon-q-credentials" }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/amazon-q-task-cli",
          "awslogs-region": "$AWS_REGION",
          "awslogs-stream-prefix": "ecs",
          "awslogs-create-group": "true"
        }
      }
    }
  ],
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "1024",
  "memory": "2048"
}
EOF

# Register task definition
echo "Registering task definition..."
aws ecs register-task-definition --cli-input-json file://amazon-q-task-cli.json

echo "ECS setup completed successfully!"
echo "S3 Bucket: $BUCKET_NAME"
echo "SNS Topic ARN: $SNS_TOPIC_ARN"
echo "Task Definition: amazon-q-task-cli"
