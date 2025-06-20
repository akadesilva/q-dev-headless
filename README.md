# Amazon Q Developer CLI Container

This project provides a Docker container that runs Amazon Q Developer CLI to automatically implement requirements from a document. It can be run locally or deployed to AWS Fargate for serverless execution.

## Overview

The container uses Amazon Q Developer CLI to:
1. Clone a repository
2. Read requirements from a specified document
3. Generate code implementations using Amazon Q
4. Commit and push changes to a new branch

## Project Structure

```
q-headless/
├── Dockerfile            # Container definition
├── README.md            # This documentation file
├── setup-fargate.sh     # Main script for Fargate setup
├── setup-iam-roles.sh   # Creates IAM roles for Fargate
├── setup-secrets.sh     # Sets up secrets in AWS Secrets Manager
├── setup-ecr.sh         # Sets up ECR and builds/pushes image
├── setup-ecs.sh         # Creates ECS cluster and task definition
├── run-fargate-task.sh  # Runs the task on Fargate
├── check-task-status.sh # Monitors task status and logs
└── scripts/             # Container scripts
    ├── expect-login.sh   # Automate Q CLI login prompts
    ├── q-authenticate.sh # Handle authentication
    ├── q-process-requirements.sh # Process requirements
    ├── sync-database.sh  # Sync Q CLI database with S3
    └── entrypoint.sh     # Container entrypoint
```

## How It Works

### Authentication Flow

The container uses a two-phase authentication approach:

1. **First Run**:
   - Container attempts to authenticate with Amazon Q Developer CLI
   - Authentication URL and code are output to the container logs
   - User must complete authentication by visiting the URL and entering the code

2. **Second Run**:
   - Container checks if authentication is complete
   - If authenticated, processes requirements and generates code

### Source Code Access

The container accesses source code by:

1. Cloning the repository specified in the REPO_URL environment variable
2. Reading requirements from the specified document
3. Making changes to the code based on the requirements

### Database Persistence

The container maintains state between runs by:

1. Downloading the Amazon Q Developer CLI database from S3 at startup (if it exists)
2. Using the database during execution
3. Uploading the updated database back to S3 before container shutdown

## Running Locally with Docker

You can run the container locally for testing:

```bash
docker build -t amazon-q-dev-cli .

docker run -it --rm \
  -e PROCESS_REQUIREMENTS=true \
  -e REPO_URL=https://github.com/yourusername/your-repo.git \
  -e INSTRUCTIONS_S3_URI=s3://your-bucket/path/to/instructions.md \
  -e BRANCH_NAME=feature-branch \
  -e Q_DATABASE_S3_URI=s3://your-bucket/path/to/database/data.sqlite3 \
  -e GIT_CREDENTIALS_SECRET_ID=amazon-q-headless/git-credentials \
  -e AMAZON_Q_CREDENTIALS_SECRET_ID=amazon-q-headless/amazon-q-credentials \
  -v ~/.aws:/root/.aws:ro \
  amazon-q-dev-cli
```

## Running on AWS Fargate

This section provides comprehensive instructions for running the Amazon Q Developer CLI Container on AWS Fargate.

### Prerequisites

- AWS CLI installed and configured with appropriate permissions
- Docker installed locally
- A VPC with at least one public subnet and security group that allows outbound traffic
- Git repository for code implementation

### Automated Setup

We've provided a set of scripts to automate the Fargate setup process. To use them:

```bash
./setup-fargate.sh
```

This script will guide you through the entire process, including:
- Setting up IAM roles
- Setting up secrets in AWS Secrets Manager
- Building and pushing the Docker image
- Creating the ECS cluster and task definition
- Running the task on Fargate
- Completing authentication
- Running the task again to process requirements

### Manual Setup Steps

If you prefer to set up manually, follow these steps:

#### 1. Set up IAM Roles and Policies

Create the necessary IAM roles:

```bash
# Create ECS Task Execution Role
aws iam create-role \
  --role-name ecsTaskExecutionRole \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "ecs-tasks.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  }'

# Attach required policies
aws iam attach-role-policy \
  --role-name ecsTaskExecutionRole \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy
aws iam attach-role-policy \
  --role-name ecsTaskExecutionRole \
  --policy-arn arn:aws:iam::aws:policy/CloudWatchLogsFullAccess

# Create Amazon Q Task Role
aws iam create-role \
  --role-name AmazonQTaskRole \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "ecs-tasks.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  }'

# Create and attach policy for Amazon Q Task Role
aws iam create-policy \
  --policy-name AmazonQTaskPolicy \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ],
        "Resource": [
          "arn:aws:s3:::*/*",
          "arn:aws:s3:::*"
        ]
      },
      {
        "Effect": "Allow",
        "Action": [
          "sns:Publish"
        ],
        "Resource": "*"
      },
      {
        "Effect": "Allow",
        "Action": [
          "secretsmanager:GetSecretValue"
        ],
        "Resource": [
          "arn:aws:secretsmanager:*:*:secret:amazon-q-headless/*"
        ]
      }
    ]
  }'

# Get the policy ARN
POLICY_ARN=$(aws iam list-policies --query "Policies[?PolicyName=='AmazonQTaskPolicy'].Arn" --output text)

# Attach policy
aws iam attach-role-policy \
  --role-name AmazonQTaskRole \
  --policy-arn $POLICY_ARN
```

#### 2. Build and Push the Docker Image

```bash
# Get AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
AWS_REGION="us-east-1"

# Create ECR repository
aws ecr create-repository --repository-name amazon-q-dev-cli

# Build Docker image
docker build -t amazon-q-dev-cli .

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Tag and push image
docker tag amazon-q-dev-cli:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/amazon-q-dev-cli:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/amazon-q-dev-cli:latest
```

#### 3. Set up AWS Secrets Manager

Create the required secrets in AWS Secrets Manager:

```bash
# Create Git credentials secret
aws secretsmanager create-secret \
  --name amazon-q-headless/git-credentials \
  --description "Git credentials for Amazon Q Headless" \
  --secret-string '{
    "token": "your-github-personal-access-token",
    "email": "your-email@example.com"
  }'

# Create Amazon Q credentials secret
aws secretsmanager create-secret \
  --name amazon-q-headless/amazon-q-credentials \
  --description "Amazon Q credentials for Amazon Q Headless" \
  --secret-string '{
    "sso_url": "https://view.awsapps.com/start",
    "region": "us-east-1"
  }'
```

#### 4. Set up S3 Bucket and SNS Topic

```bash
# Create S3 bucket
BUCKET_NAME="amazon-q-demo-$(date +%s)"
aws s3 mb s3://$BUCKET_NAME

# Create sample instructions file
cat > dummy_instructions.md << 'EOF'
## Feature Requirements
- Create a simple REST API endpoint that returns the current time
- Add a health check endpoint that returns system status
## End Requirements
EOF

# Upload instructions to S3
aws s3 cp dummy_instructions.md s3://$BUCKET_NAME/q-headless/dummy_instructions.md

# Create SNS topic for login notifications
SNS_TOPIC_ARN=$(aws sns create-topic --name q-dev-cli-login --query 'TopicArn' --output text)
```

#### 5. Create ECS Cluster and Task Definition

```bash
# Create ECS cluster
aws ecs create-cluster --cluster-name amazon-q-cluster

# Create task definition JSON
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
        { "name": "REPO_URL", "value": "https://github.com/yourusername/your-repo.git" },
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
  "cpu": "2048",
  "memory": "8192"
}
EOF

# Register task definition
aws ecs register-task-definition --cli-input-json file://amazon-q-task-cli.json
```

#### 6. Run the Task in Fargate

```bash
# You need to provide your subnet ID and security group ID
SUBNET_ID="your-subnet-id"
SECURITY_GROUP_ID="your-security-group-id"

# Run the task
TASK_ARN=$(aws ecs run-task \
  --cluster amazon-q-cluster \
  --task-definition amazon-q-task-cli \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_ID],securityGroups=[$SECURITY_GROUP_ID],assignPublicIp=ENABLED}" \
  --query 'tasks[0].taskArn' \
  --output text)

# Extract task ID from ARN
TASK_ID=$(echo $TASK_ARN | awk -F'/' '{print $3}')
```

#### 7. Complete Authentication

```bash
# Wait for task to start running
aws ecs wait tasks-running --cluster amazon-q-cluster --tasks $TASK_ARN

# Get logs to find authentication URL and code
aws logs get-log-events \
  --log-group-name /ecs/amazon-q-task-cli \
  --log-stream-name ecs/amazon-q-container/$TASK_ID \
  --output text

# After completing authentication via the URL and code in the logs, run the task again
```

#### 8. Run the Task Again to Process Requirements

```bash
# Run the task again
aws ecs run-task \
  --cluster amazon-q-cluster \
  --task-definition amazon-q-task-cli \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_ID],securityGroups=[$SECURITY_GROUP_ID],assignPublicIp=ENABLED}"
```

## Environment Variables

- `PROCESS_REQUIREMENTS`: Set to "true" to process requirements
- `REPO_URL`: URL of the Git repository to clone
- `INSTRUCTIONS_S3_URI`: S3 URI of the instructions file
- `BRANCH_NAME`: Git branch name for implementation
- `COMMIT_MESSAGE`: Git commit message
- `LOGIN_SNS_TOPIC`: SNS topic ARN for login notifications
- `Q_DATABASE_S3_URI`: S3 URI for storing/retrieving the Q CLI database
- `GIT_CREDENTIALS_SECRET_ID`: Secret ID for Git credentials in AWS Secrets Manager
- `AMAZON_Q_CREDENTIALS_SECRET_ID`: Secret ID for Amazon Q credentials in AWS Secrets Manager

## AWS Secrets Manager Setup

The container requires two secrets to be set up in AWS Secrets Manager:

1. **Git Credentials Secret** (default ID: `amazon-q-headless/git-credentials`):
   ```json
   {
     "token": "your-github-personal-access-token",
     "email": "your-email@example.com"
   }
   ```

2. **Amazon Q Credentials Secret** (default ID: `amazon-q-headless/amazon-q-credentials`):
   ```json
   {
     "sso_url": "https://view.awsapps.com/start",
     "region": "us-east-1"
   }
   ```

You can create these secrets using the provided `setup-secrets.sh` script or manually through the AWS Management Console or AWS CLI.

## Authentication Process

When the container runs for the first time:

1. It will output an authentication URL and code to the container logs
2. A developer must visit the URL and enter the code
3. After authentication is complete, run the container again to process requirements

## Requirements Format

The requirements document should be a Markdown file with sections marked by headers:

```markdown
## Feature Requirements
- Implement a user authentication system
- Add password reset functionality
- Create user profile page
## End Requirements
```

The container will extract the section between `Feature Requirements` and `End Requirements` markers.

## Troubleshooting

### Authentication Issues

If you encounter authentication issues:
- Check that the authentication URL and code were correctly entered
- Check the task logs for any error messages
- Verify that the Amazon Q credentials secret contains the correct SSO URL and region

### Task Failures

If the task fails:
- Check the CloudWatch logs for error messages
- Verify that the IAM roles have the necessary permissions
- Ensure the S3 bucket and objects are accessible

### Network Issues

If the task cannot access the internet:
- Verify that the subnet has a route to an Internet Gateway
- Check that the security group allows outbound traffic
- Ensure that public IP assignment is enabled for the task
