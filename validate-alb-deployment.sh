#!/bin/bash

set -e  # Exit immediately if a command fails

# Variables (Update as needed)
ALB_NAME="payment-api-alb"
TARGET_GROUP_NAME="payment-api-target-group"
REGION="us-east-1"

echo "🚀 Starting ALB Deployment Validation..."

# 🔍 Check ALB
echo "🔎 Checking if ALB '$ALB_NAME' exists..."
ALB_ARN=$(aws elbv2 describe-load-balancers --names "$ALB_NAME" --region "$REGION" --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null)

if [ "$ALB_ARN" == "None" ]; then
    echo "❌ ALB '$ALB_NAME' does not exist!"
    exit 1
else
    echo "✅ ALB Found: $ALB_ARN"
fi

# 🔍 Check ALB State
echo "🔎 Checking ALB State..."
ALB_STATE=$(aws elbv2 describe-load-balancers --load-balancer-arns "$ALB_ARN" --region "$REGION" --query 'LoadBalancers[0].State.Code' --output text)

if [ "$ALB_STATE" == "active" ]; then
    echo "✅ ALB is Active and Running."
else
    echo "❌ ALB is in '$ALB_STATE' state! Please check AWS Console."
    exit 1
fi

# 🔍 Check Target Group
echo "🔎 Checking if Target Group '$TARGET_GROUP_NAME' exists..."
TARGET_GROUP_ARN=$(aws elbv2 describe-target-groups --names "$TARGET_GROUP_NAME" --region "$REGION" --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null)

if [ "$TARGET_GROUP_ARN" == "None" ]; then
    echo "❌ Target Group '$TARGET_GROUP_NAME' does not exist!"
    exit 1
else
    echo "✅ Target Group Found: $TARGET_GROUP_ARN"
fi

# 🔍 Check Instance Health
echo "🔎 Checking Target Group Health Status..."
HEALTH_STATUS=$(aws elbv2 describe-target-health --target-group-arn "$TARGET_GROUP_ARN" --region "$REGION" --query 'TargetHealthDescriptions[*].[Target.Id, TargetHealth.State]' --output text)

if [ -z "$HEALTH_STATUS" ]; then
    echo "❌ No instances registered in the Target Group!"
    exit 1
else
    echo "✅ Target Group Health Check Passed!"
    echo "📋 Instance Health Details:"
    echo "$HEALTH_STATUS"
fi

# 🔍 Get ALB DNS
echo "🔎 Fetching ALB DNS Name..."
ALB_DNS=$(aws elbv2 describe-load-balancers --load-balancer-arns "$ALB_ARN" --region "$REGION" --query 'LoadBalancers[0].DNSName' --output text)

if [ -z "$ALB_DNS" ]; then
    echo "❌ Failed to retrieve ALB DNS Name!"
    exit 1
else
    echo "🌐 ALB is accessible at: http://$ALB_DNS"
fi

echo "✅ ALB Deployment Validation Complete!"

