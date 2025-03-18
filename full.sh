#!/bin/bash

set -e  # Exit script on error

AWS_REGION="us-east-1"
ALB_NAME="payment-api-alb"
TARGET_GROUP_NAME="payment-api-target-group"
SECURITY_GROUP_NAME="payment-api-alb-sg"

echo "🚀 Starting Full Cleanup Process..."

# 🛑 1️⃣ **Delete Load Balancer**
ALB_ARN=$(aws elbv2 describe-load-balancers --names "$ALB_NAME" --query "LoadBalancers[0].LoadBalancerArn" --output text 2>/dev/null || echo "None")

if [[ "$ALB_ARN" != "None" ]]; then
    echo "❌ Deleting ALB: $ALB_NAME"
    aws elbv2 delete-load-balancer --load-balancer-arn "$ALB_ARN" --region "$AWS_REGION"
    sleep 20  # Wait for AWS to process deletion
else
    echo "✅ ALB does not exist or already removed."
fi

# 🛑 2️⃣ **Delete Target Group**
TARGET_GROUP_ARN=$(aws elbv2 describe-target-groups --names "$TARGET_GROUP_NAME" --query "TargetGroups[0].TargetGroupArn" --output text 2>/dev/null || echo "None")

if [[ "$TARGET_GROUP_ARN" != "None" ]]; then
    echo "❌ Deleting Target Group: $TARGET_GROUP_NAME"
    aws elbv2 delete-target-group --target-group-arn "$TARGET_GROUP_ARN" --region "$AWS_REGION"
else
    echo "✅ Target Group does not exist or already removed."
fi

# 🛑 3️⃣ **Terminate EC2 Instances**
INSTANCE_IDS=$(aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" --query "Reservations[*].Instances[*].InstanceId" --output text)

if [[ -n "$INSTANCE_IDS" ]]; then
    echo "❌ Terminating EC2 Instances: $INSTANCE_IDS"
    aws ec2 terminate-instances --instance-ids $INSTANCE_IDS --region "$AWS_REGION"

    # Wait for termination
    for INSTANCE_ID in $INSTANCE_IDS; do
        echo "⌛ Waiting for $INSTANCE_ID to terminate..."
        aws ec2 wait instance-terminated --instance-ids "$INSTANCE_ID" --region "$AWS_REGION"
    done
else
    echo "✅ No running EC2 instances found."
fi

# 🛑 4️⃣ **Delete Security Group (after ALB & EC2)**
SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=$SECURITY_GROUP_NAME" --query "SecurityGroups[0].GroupId" --output text 2>/dev/null || echo "")

if [[ -n "$SG_ID" ]]; then
    echo "❌ Deleting Security Group: $SG_ID"
    aws ec2 delete-security-group --group-id "$SG_ID" --region "$AWS_REGION"
else
    echo "✅ Security Group does not exist or already removed."
fi

# 🛑 5️⃣ **Detach & Delete Subnets**
SUBNET_IDS=$(aws ec2 describe-subnets --query "Subnets[*].SubnetId" --output text)

if [[ -n "$SUBNET_IDS" ]]; then
    echo "❌ Deleting Subnets: $SUBNET_IDS"

    for SUBNET_ID in $SUBNET_IDS; do
        echo "🔍 Checking dependencies for subnet: $SUBNET_ID"

        # Detach any network interfaces (otherwise, AWS won't allow deletion)
        ENI_IDS=$(aws ec2 describe-network-interfaces --filters "Name=subnet-id,Values=$SUBNET_ID" --query "NetworkInterfaces[*].NetworkInterfaceId" --output text)

        for ENI_ID in $ENI_IDS; do
            echo "❌ Deleting Network Interface: $ENI_ID"
            aws ec2 delete-network-interface --network-interface-id "$ENI_ID" --region "$AWS_REGION"
        done

        echo "❌ Deleting Subnet: $SUBNET_ID"
        aws ec2 delete-subnet --subnet-id "$SUBNET_ID" --region "$AWS_REGION"
    done
else
    echo "✅ No subnets found to delete."
fi

# 🛑 6️⃣ **Detach Internet Gateways & Delete VPCs**
VPC_IDS=$(aws ec2 describe-vpcs --query "Vpcs[*].VpcId" --output text)

if [[ -n "$VPC_IDS" ]]; then
    echo "❌ Deleting VPCs: $VPC_IDS"

    for VPC_ID in $VPC_IDS; do
        echo "🔍 Checking dependencies for VPC: $VPC_ID"

        # Detach and delete Internet Gateways
        IGW_ID=$(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC_ID" --query "InternetGateways[0].InternetGatewayId" --output text 2>/dev/null || echo "")

        if [[ -n "$IGW_ID" ]]; then
            echo "❌ Detaching and Deleting Internet Gateway: $IGW_ID"
            aws ec2 detach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID" --region "$AWS_REGION"
            aws ec2 delete-internet-gateway --internet-gateway-id "$IGW_ID" --region "$AWS_REGION"
        fi

        # Delete the VPC
        echo "❌ Deleting VPC: $VPC_ID"
        aws ec2 delete-vpc --vpc-id "$VPC_ID" --region "$AWS_REGION"
    done
else
    echo "✅ No VPCs found to delete."
fi

echo "🎉 Full Cleanup Process Completed!"

