#!/bin/bash
set -e

echo "====================================================="
echo "Amazon Q Developer CLI Container - Fargate Setup Guide"
echo "====================================================="
echo ""
echo "This script will guide you through setting up and running"
echo "the Amazon Q Developer CLI Container on AWS Fargate."
echo ""
echo "The setup process has the following steps:"
echo "1. Set up IAM roles and policies"
echo "2. Set up ECR repository and build/push Docker image"
echo "3. Set up ECS cluster and task definition"
echo "4. Run the Fargate task"
echo "5. Complete authentication"
echo "6. Run the task again to process requirements"
echo ""
echo "Press Enter to continue or Ctrl+C to exit..."
read

echo ""
echo "Step 1: Setting up IAM roles and policies..."
echo "-------------------------------------------"
./setup-iam-roles.sh
echo ""
echo "Press Enter to continue..."
read

echo ""
echo "Step 2: Setting up secrets in AWS Secrets Manager..."
echo "---------------------------------------------------"
./setup-secrets.sh
echo ""
echo "IMPORTANT: Please update the secret values with your actual credentials using the AWS Management Console or AWS CLI."
echo "Press Enter to continue..."
read

echo ""
echo "Step 3: Setting up ECR repository and building/pushing Docker image..."
echo "-------------------------------------------------------------------"
./setup-ecr.sh
echo ""
echo "Press Enter to continue..."
read

echo ""
echo "Step 4: Setting up ECS cluster and task definition..."
echo "---------------------------------------------------"
./setup-ecs.sh
echo ""
echo "Press Enter to continue..."
read

echo ""
echo "Step 5: Running the Fargate task..."
echo "---------------------------------"
echo "You need to provide a subnet ID and security group ID from your VPC."
echo "The subnet should have access to the internet (via an Internet Gateway)."
echo "The security group should allow outbound traffic."
echo ""
read -p "Enter subnet ID (e.g., subnet-12345678): " SUBNET_ID
read -p "Enter security group ID (e.g., sg-12345678): " SECURITY_GROUP_ID

./run-fargate-task.sh $SUBNET_ID $SECURITY_GROUP_ID
echo ""
echo "Press Enter to continue..."
read

echo ""
echo "Step 6: Complete authentication..."
echo "--------------------------------"
echo "1. Check the logs above for the authentication URL and code"
echo "2. Visit the URL and enter the code"
echo "3. After authentication is complete, press Enter to update the Parameter Store"
read

aws ssm put-parameter --name "/amazon-q/auth/status" --value "completed" --type String --overwrite
echo "Parameter Store updated successfully!"
echo ""
echo "Press Enter to continue..."
read

echo ""
echo "Step 7: Running the task again to process requirements..."
echo "------------------------------------------------------"
./run-fargate-task.sh $SUBNET_ID $SECURITY_GROUP_ID
echo ""
echo "Press Enter to continue..."
read

echo ""
echo "Monitoring the task and checking results..."
echo "----------------------------------------"
./check-task-status.sh

echo ""
echo "Setup complete! The Amazon Q Developer CLI Container is now running on Fargate."
echo "You can check the task status and logs at any time by running:"
echo "./check-task-status.sh"
echo ""
echo "For more information, refer to the FARGATE_SETUP.md file."
