#!/bin/bash
set -e

# List tasks
echo "Listing tasks in amazon-q-cluster..."
TASKS=$(aws ecs list-tasks --cluster amazon-q-cluster --query 'taskArns' --output text)

if [ -z "$TASKS" ]; then
    echo "No tasks found in the cluster."
    exit 0
fi

echo "Found tasks: $TASKS"

# For each task, get details and logs
for TASK_ARN in $TASKS; do
    TASK_ID=$(echo $TASK_ARN | awk -F'/' '{print $3}')
    
    echo "Getting details for task $TASK_ID..."
    aws ecs describe-tasks --cluster amazon-q-cluster --tasks $TASK_ARN --query 'tasks[0].lastStatus' --output text
    
    echo "Fetching logs for task $TASK_ID..."
    aws logs get-log-events \
      --log-group-name /ecs/amazon-q-task-cli \
      --log-stream-name ecs/amazon-q-container/$TASK_ID \
      --output text
    
    echo "-----------------------------------"
done
