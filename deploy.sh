#!/bin/bash

# AWS Region
AWS_REGION="us-east-1"

# EC2 Configuration
AMI_ID="ami-0071e9867650bf71b" 
INSTANCE_TYPE="t2.micro"
KEY_NAME="ney_key01"
SECURITY_GROUP_NAME="payment-api-sg"
IAM_ROLE="PaymentProcessingRole"
TAG_NAME="PaymentProcessingInstance"
LOG_FILE="ec2-deployment.log"

echo "Starting EC2 Deployment..." | tee $LOG_FILE

# Check for Key Pair
echo "Checking for Key Pair..."
aws ec2 describe-key-pairs --key-names "$KEY_NAME" --region "$AWS_REGION" > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "Key Pair '$KEY_NAME' not found. Creating..."
    aws ec2 create-key-pair --key-name "$KEY_NAME" --query 'KeyMaterial' --output text > "$KEY_NAME.pem"
    chmod 400 "$KEY_NAME.pem"
    echo "Key Pair '$KEY_NAME' created."
else
    echo "Key Pair '$KEY_NAME' exists."
fi

# Get the default VPC ID
echo "Retrieving VPC ID..."
VPC_ID=$(aws ec2 describe-vpcs --query "Vpcs[?IsDefault==true].VpcId" --output text --region "$AWS_REGION")

if [ -z "$VPC_ID" ]; then
    echo "❌ Failed to retrieve VPC ID. Exiting..."
    exit 1
fi
echo "Using VPC: $VPC_ID"

# Check for Security Group in the same VPC
echo "Checking for Security Group..."
SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=$SECURITY_GROUP_NAME" "Name=vpc-id,Values=$VPC_ID" --query "SecurityGroups[0].GroupId" --output text --region "$AWS_REGION" 2>/dev/null)

if [[ "$SG_ID" == "None" || -z "$SG_ID" ]]; then
    echo "Security Group '$SECURITY_GROUP_NAME' not found. Creating..."
    SG_ID=$(aws ec2 create-security-group --group-name "$SECURITY_GROUP_NAME" --description "Security group for payment processing API" --vpc-id "$VPC_ID" --query "GroupId" --output text --region "$AWS_REGION")

    if [ -z "$SG_ID" ]; then
        echo "❌ Failed to create Security Group. Exiting..."
        exit 1
    fi
    echo "Security Group Created: $SG_ID"

    # Add Ingress Rules
    echo "Adding Security Group Rules..."
    aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 22 --cidr 0.0.0.0/0 --region "$AWS_REGION"
    aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 3000 --cidr 0.0.0.0/0 --region "$AWS_REGION"
    echo "Security Group Rules Set."
else
    echo "Using existing Security Group: $SG_ID"
fi

# Get a subnet from the same VPC
echo "Getting Subnet ID..."
SUBNET_ID=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[0].SubnetId' --output text --region "$AWS_REGION")

if [ -z "$SUBNET_ID" ]; then
    echo "❌ Failed to retrieve Subnet ID. Exiting..."
    exit 1
fi
echo "Using Subnet: $SUBNET_ID"

# Validate IAM Role
echo "Checking IAM Role..."
INSTANCE_PROFILE_NAME=$(aws iam get-instance-profile --instance-profile-name "$IAM_ROLE" --query 'InstanceProfile.Arn' --output text 2>/dev/null)

if [ -z "$INSTANCE_PROFILE_NAME" ]; then
    echo "❌ IAM Role '$IAM_ROLE' not found. Make sure it exists in AWS IAM."
    exit 1
fi
echo "Using IAM Role: $IAM_ROLE"

# Launch EC2 Instance
echo "Launching EC2 Instance..."
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id "$AMI_ID" \
    --instance-type "$INSTANCE_TYPE" \
    --key-name "$KEY_NAME" \
    --security-group-ids "$SG_ID" \
    --subnet-id "$SUBNET_ID" \
    --iam-instance-profile Name="$IAM_ROLE" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$TAG_NAME}]" \
    --query "Instances[0].InstanceId" \
    --output text --region "$AWS_REGION")

if [ -z "$INSTANCE_ID" ]; then
    echo "Failed to launch EC2 instance. Check logs for details." | tee -a $LOG_FILE
    exit 1
fi
echo "EC2 Instance Launched: $INSTANCE_ID" | tee -a $LOG_FILE

# Get Public IP
echo "Fetching Public IP..."
PUBLIC_IP=""
while [ -z "$PUBLIC_IP" ]; do
    sleep 5
    PUBLIC_IP=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --query "Reservations[0].Instances[0].PublicIpAddress" --output text --region "$AWS_REGION")
done
echo "EC2 Instance Public IP: $PUBLIC_IP" | tee -a $LOG_FILE

echo "Deployment Complete!" | tee -a $LOG_FILE
