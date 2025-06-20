#!/bin/bash
set -e

# Create ECS Task Execution Role if it doesn't exist
echo "Creating ECS Task Execution Role (if it doesn't exist)..."
aws iam get-role --role-name ecsTaskExecutionRole > /dev/null 2>&1 || \
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

# Attach CloudWatch Logs policy to ECS Task Execution Role
echo "Attaching CloudWatch Logs policy to ECS Task Execution Role..."
aws iam attach-role-policy \
  --role-name ecsTaskExecutionRole \
  --policy-arn arn:aws:iam::aws:policy/CloudWatchLogsFullAccess

# Create Amazon Q Task Role if it doesn't exist
echo "Creating Amazon Q Task Role (if it doesn't exist)..."
aws iam get-role --role-name AmazonQTaskRole > /dev/null 2>&1 || \
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

# Create policy for Amazon Q Task Role if it doesn't exist
echo "Creating policy for Amazon Q Task Role (if it doesn't exist)..."
POLICY_ARN=$(aws iam list-policies --query "Policies[?PolicyName=='AmazonQTaskPolicy'].Arn" --output text)

if [ -z "$POLICY_ARN" ]; then
  echo "Creating AmazonQTaskPolicy..."
  POLICY_ARN=$(aws iam create-policy \
    --policy-name AmazonQTaskPolicy \
    --policy-document '{
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Action": [
            "ssm:GetParameter",
            "ssm:PutParameter"
          ],
          "Resource": "arn:aws:ssm:*:*:parameter/amazon-q/*"
        },
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
    }' \
    --query 'Policy.Arn' --output text)
else
  echo "AmazonQTaskPolicy already exists."
fi

# Attach policy to Amazon Q Task Role
echo "Attaching policy to Amazon Q Task Role..."
aws iam attach-role-policy \
  --role-name AmazonQTaskRole \
  --policy-arn $POLICY_ARN

echo "IAM roles and policies created successfully!"
