#!/bin/bash
set -e

# Get AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
AWS_REGION="us-east-1"

# Create ECR repository if it doesn't exist
echo "Creating ECR repository (if it doesn't exist)..."
aws ecr describe-repositories --repository-names amazon-q-dev-cli > /dev/null 2>&1 || \
aws ecr create-repository --repository-name amazon-q-dev-cli

# Check if Dockerfile exists
if [ ! -f "Dockerfile" ]; then
  echo "Creating sample Dockerfile..."
  cat > Dockerfile << 'EOF'
FROM amazonlinux:2

# Install dependencies
RUN yum update -y && \
    yum install -y git python3 python3-pip unzip jq expect && \
    yum clean all

# Install AWS CLI
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm -rf aws awscliv2.zip

# Install Amazon Q Developer CLI
RUN curl -L https://d3op2l77j7wnti.cloudfront.net/amazon-q-cli/amazonq-cli-linux-x86_64-latest.tar.gz | tar -xz -C /tmp && \
    mv /tmp/amazonq-cli-* /usr/local/bin/q && \
    chmod +x /usr/local/bin/q

# Create directory for scripts
RUN mkdir -p /app/scripts

# Copy scripts
COPY scripts/ /app/scripts/
RUN chmod +x /app/scripts/*.sh

# Set working directory
WORKDIR /app

# Set entrypoint
ENTRYPOINT ["/app/scripts/entrypoint.sh"]
EOF

  # Create scripts directory if it doesn't exist
  mkdir -p scripts

  # Create sample entrypoint script
  echo "Creating sample entrypoint script..."
  cat > scripts/entrypoint.sh << 'EOF'
#!/bin/bash
set -e

echo "Amazon Q Developer CLI Container started"
echo "This is a sample entrypoint script"
echo "In a real implementation, this would handle authentication and process requirements"

# Keep container running for testing
echo "Container is now running. Press Ctrl+C to stop."
tail -f /dev/null
EOF

  chmod +x scripts/entrypoint.sh
  
  echo "Created sample Dockerfile and scripts. Please replace with your actual implementation before building."
  echo "Skipping Docker build and push steps."
  exit 0
fi

# Build Docker image
echo "Building Docker image..."
docker build -t amazon-q-dev-cli .

# Login to ECR
echo "Logging in to ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Tag and push image
echo "Tagging and pushing image to ECR..."
docker tag amazon-q-dev-cli:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/amazon-q-dev-cli:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/amazon-q-dev-cli:latest

echo "Docker image pushed to ECR successfully!"
echo "ECR Image URI: $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/amazon-q-dev-cli:latest"
