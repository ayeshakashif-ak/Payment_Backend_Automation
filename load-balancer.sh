#!/bin/bash

set -e

# Variables (Update as needed)
SECURITY_GROUP_NAME="payment-api-alb-sg"
TARGET_GROUP_NAME="payment-api-target-group"
ALB_NAME="payment-api-alb"
VPC_ID="vpc-0634d07f09c3068d6" 
PORT=80
REGION="us-east-1"

# Start
echo "\U0001F680 Configuring Application Load Balancer (ALB)..."

# Check if Security Group exists
echo "Checking for Security Group..."
SECURITY_GROUP_ID=$(aws ec2 describe-security-groups --region "$REGION" --query "SecurityGroups[?GroupName=='$SECURITY_GROUP_NAME'].GroupId" --output text)

if [ "$SECURITY_GROUP_ID" = "None" ]; then
    echo "Security Group '$SECURITY_GROUP_NAME' not found. Creating..."
    SECURITY_GROUP_ID=$(aws ec2 create-security-group --group-name "$SECURITY_GROUP_NAME" --description "Security Group for ALB" --vpc-id "$VPC_ID" --region "$REGION" --query 'GroupId' --output text)
    
    # Allow HTTP and HTTPS traffic
    aws ec2 authorize-security-group-ingress --group-id "$SECURITY_GROUP_ID" --protocol tcp --port 80 --cidr 0.0.0.0/0 --region "$REGION"
    aws ec2 authorize-security-group-ingress --group-id "$SECURITY_GROUP_ID" --protocol tcp --port 443 --cidr 0.0.0.0/0 --region "$REGION"
    echo "Security Group Created: $SECURITY_GROUP_ID"
else
    echo "Security Group exists: $SECURITY_GROUP_ID"
fi

# Fetch Subnets
echo "Fetching Subnets for ALB..."
SUBNETS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --region "$REGION" --query 'Subnets[*].SubnetId' --output text)
echo "Using Subnets: $SUBNETS"

# Check if ALB exists
echo "Checking for existing ALB..."
ALB_ARN=$(aws elbv2 describe-load-balancers --names "$ALB_NAME" --region "$REGION" --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null)

if [ "$ALB_ARN" = "None" ]; then
    echo "ALB not found. Creating..."
    ALB_ARN=$(aws elbv2 create-load-balancer --name "$ALB_NAME" --type application --security-groups "$SECURITY_GROUP_ID" --subnets $SUBNETS --region "$REGION" --query 'LoadBalancers[0].LoadBalancerArn' --output text)
    echo "ALB Created: $ALB_ARN"
else
    echo "ALB exists: $ALB_ARN"
fi

# Check Target Group
echo "Checking for Target Group..."
TARGET_GROUP_ARN=$(aws elbv2 describe-target-groups --names "$TARGET_GROUP_NAME" --region "$REGION" --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null)

if [ "$TARGET_GROUP_ARN" = "None" ]; then
    echo "Target Group not found. Creating..."
    TARGET_GROUP_ARN=$(aws elbv2 create-target-group --name "$TARGET_GROUP_NAME" --protocol HTTP --port "$PORT" --vpc-id "$VPC_ID" --region "$REGION" --query 'TargetGroups[0].TargetGroupArn' --output text)
    echo "Target Group Created: $TARGET_GROUP_ARN"
else
    echo "Target Group exists: $TARGET_GROUP_ARN"
fi

# Get Running EC2 Instances
echo "Fetching Running EC2 Instances..."
INSTANCE_IDS=$(aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" --region "$REGION" --query 'Reservations[*].Instances[*].InstanceId' --output text)

if [ -n "$INSTANCE_IDS" ]; then
    echo "Found instances: $INSTANCE_IDS"
    echo "Registering Instances to Target Group..."
    aws elbv2 register-targets --target-group-arn "$TARGET_GROUP_ARN" --targets $(for i in $INSTANCE_IDS; do echo "Id=$i"; done) --region "$REGION"
    echo "Instances Registered."
else
    echo "No running instances found to register."
fi

# Check Listener
echo "Checking for Listener..."
LISTENER_ARN=$(aws elbv2 describe-listeners --load-balancer-arn "$ALB_ARN" --region "$REGION" --query 'Listeners[0].ListenerArn' --output text 2>/dev/null)

if [ "$LISTENER_ARN" = "None" ]; then
    echo "Listener not found. Creating..."
    LISTENER_ARN=$(aws elbv2 create-listener --load-balancer-arn "$ALB_ARN" --protocol HTTP --port "$PORT" --default-actions Type=forward,TargetGroupArn="$TARGET_GROUP_ARN" --region "$REGION" --query 'Listeners[0].ListenerArn' --output text)
    echo "Listener Created: $LISTENER_ARN"
else
    echo "Listener exists: $LISTENER_ARN"
fi

# Fetch ALB DNS Name
echo "Fetching ALB DNS Name..."
ALB_DNS=$(aws elbv2 describe-load-balancers --load-balancer-arns "$ALB_ARN" --region "$REGION" --query 'LoadBalancers[0].DNSName' --output text)

echo "ALB is accessible at: http://$ALB_DNS"
echo "ALB Configuration Complete!"
