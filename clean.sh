#!/bin/bash

set -e  # Exit script on error
set -o pipefail  # Catch pipeline errors
set -u  # Treat unset variables as errors

# AWS Region
AWS_REGION="us-east-1"

# Resource Names
ALB_NAME="payment-api-alb"
TARGET_GROUP_NAME="payment-api-target-group"
SECURITY_GROUP_NAME="payment-api-alb-sg"

echo "🚀 Starting Cleanup Process..."

# 🔍 Fetch ALB Information
ALB_ARN=$(aws elbv2 describe-load-balancers --names "$ALB_NAME" --region "$AWS_REGION" --query "LoadBalancers[0].LoadBalancerArn" --output text 2>/dev/null || echo "")

if [[ -n "$ALB_ARN" ]]; then
    echo "🔍 ALB found: $ALB_ARN"

    # 🛑 Delete Listeners
    LISTENER_ARNS=$(aws elbv2 describe-listeners --load-balancer-arn "$ALB_ARN" --region "$AWS_REGION" --query "Listeners[*].ListenerArn" --output text)
    if [[ -n "$LISTENER_ARNS" ]]; then
        for LISTENER_ARN in $LISTENER_ARNS; do
            echo "❌ Deleting Listener: $LISTENER_ARN"
            aws elbv2 delete-listener --listener-arn "$LISTENER_ARN" --region "$AWS_REGION"
        done
    fi

    # ❌ Delete ALB
    echo "❌ Deleting ALB: $ALB_ARN"
    aws elbv2 delete-load-balancer --load-balancer-arn "$ALB_ARN" --region "$AWS_REGION"
else
    echo "✅ ALB does not exist or already removed."
fi

# 🔍 Fetch and Delete Target Group
TG_ARN=$(aws elbv2 describe-target-groups --names "$TARGET_GROUP_NAME" --region "$AWS_REGION" --query "TargetGroups[0].TargetGroupArn" --output text 2>/dev/null || echo "")

if [[ -n "$TG_ARN" ]]; then
    echo "❌ Deleting Target Group: $TG_ARN"
    aws elbv2 delete-target-group --target-group-arn "$TG_ARN" --region "$AWS_REGION"
else
    echo "✅ Target Group does not exist or already removed."
fi

# 🔍 Fetch Running EC2 Instances
INSTANCE_IDS=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=payment-api-instance" "Name=instance-state-name,Values=running" --query "Reservations[*].Instances[*].InstanceId" --output text)

if [[ -n "$INSTANCE_IDS" ]]; then
    echo "❌ Terminating EC2 Instances: $INSTANCE_IDS"
    aws ec2 terminate-instances --instance-ids $INSTANCE_IDS --region "$AWS_REGION"
    echo "⏳ Waiting for instances to terminate..."
    aws ec2 wait instance-terminated --instance-ids $INSTANCE_IDS --region "$AWS_REGION"
else
    echo "✅ No running EC2 instances found."
fi

# 🔍 Fetch and Delete Security Group
SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=$SECURITY_GROUP_NAME" --query "SecurityGroups[0].GroupId" --output text 2>/dev/null || echo "")

if [[ -n "$SG_ID" ]]; then
    echo "❌ Deleting Security Group: $SG_ID"
    aws ec2 delete-security-group --group-id "$SG_ID" --region "$AWS_REGION"
else
    echo "✅ Security Group does not exist or already removed."
fi

echo "✅ Cleanup Completed!"
