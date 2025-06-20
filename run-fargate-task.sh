#!/bin/bash
set -e

# Check if subnet ID and security group ID are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <subnet-id> <security-group-id>"
    echo "Example: $0 subnet-12345678 sg-12345678"
    exit 1
fi

SUBNET_ID=$1
SECURITY_GROUP_ID=$2

# Validate subnet ID
echo "Validating subnet ID..."
SUBNET_CHECK=$(aws ec2 describe-subnets --subnet-ids $SUBNET_ID --query 'Subnets[0].SubnetId' --output text 2>/dev/null || echo "INVALID")
if [ "$SUBNET_CHECK" == "INVALID" ]; then
    echo "Error: Invalid subnet ID. Please provide a valid subnet ID."
    exit 1
fi

# Validate security group ID
echo "Validating security group ID..."
SG_CHECK=$(aws ec2 describe-security-groups --group-ids $SECURITY_GROUP_ID --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || echo "INVALID")
if [ "$SG_CHECK" == "INVALID" ]; then
    echo "Error: Invalid security group ID. Please provide a valid security group ID."
    exit 1
fi

# Run the task in Fargate
echo "Running task in Fargate..."
TASK_ARN=$(aws ecs run-task \
  --cluster amazon-q-cluster \
  --task-definition amazon-q-task-cli \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_ID],securityGroups=[$SECURITY_GROUP_ID],assignPublicIp=ENABLED}" \
  --query 'tasks[0].taskArn' \
  --output text)

# Extract task ID from ARN
TASK_ID=$(echo $TASK_ARN | awk -F'/' '{print $3}')

echo "Task started with ID: $TASK_ID"
echo "Waiting for task to start running..."

# Wait for task to start running
aws ecs wait tasks-running --cluster amazon-q-cluster --tasks $TASK_ARN

echo "Task is now running. Waiting for logs to be available..."
sleep 10

# Get logs
echo "Fetching logs from CloudWatch..."
aws logs get-log-events \
  --log-group-name /ecs/amazon-q-task-cli \
  --log-stream-name ecs/amazon-q-container/$TASK_ID \
  --output text

echo ""
echo "To complete authentication:"
echo "1. Look for the authentication URL and code in the logs above"
echo "2. Visit the URL and enter the code"
echo "3. After authentication, run the following command:"
echo "   aws ssm put-parameter --name \"/amazon-q/auth/status\" --value \"completed\" --type String --overwrite"
echo "4. Then run this script again to process requirements"
