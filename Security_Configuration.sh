#!/bin/bash
set -e  # Exit script on error

# Set AWS Region (modify if needed)
AWS_REGION="us-east-1"

# Define existing VPC ID (modify if necessary)
VPC_ID=$(aws ec2 describe-vpcs --query "Vpcs[0].VpcId" --output text --region $AWS_REGION)
echo "Using VPC: $VPC_ID"

# === Security Group Configuration ===
echo "Creating Security Groups..."

# ALB Security Group (Allows HTTP/HTTPS)
ALB_SG_ID=$(aws ec2 create-security-group --group-name ALB-SG --description "ALB Security Group" --vpc-id $VPC_ID --query "GroupId" --output text)
aws ec2 authorize-security-group-ingress --group-id $ALB_SG_ID --protocol tcp --port 80 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $ALB_SG_ID --protocol tcp --port 443 --cidr 0.0.0.0/0
echo "ALB Security Group Created: $ALB_SG_ID"

# EC2 Security Group (Allows traffic from ALB)
EC2_SG_ID=$(aws ec2 create-security-group --group-name EC2-SG --description "EC2 Security Group" --vpc-id $VPC_ID --query "GroupId" --output text)
aws ec2 authorize-security-group-ingress --group-id $EC2_SG_ID --protocol tcp --port 80 --source-group $ALB_SG_ID
aws ec2 authorize-security-group-ingress --group-id $EC2_SG_ID --protocol tcp --port 22 --cidr 0.0.0.0/0  # Modify this in production!
echo "EC2 Security Group Created: $EC2_SG_ID"

# === Network ACL Configuration ===
echo "Creating Network ACL for PCI DSS Compliance..."
NACL_ID=$(aws ec2 create-network-acl --vpc-id $VPC_ID --query "NetworkAcl.NetworkAclId" --output text)
echo "NACL Created: $NACL_ID"

# Allow inbound HTTP & HTTPS
aws ec2 create-network-acl-entry --network-acl-id $NACL_ID --rule-number 100 --protocol tcp --port-range From=80,To=80 --egress --cidr-block 0.0.0.0/0 --rule-action allow
aws ec2 create-network-acl-entry --network-acl-id $NACL_ID --rule-number 110 --protocol tcp --port-range From=443,To=443 --egress --cidr-block 0.0.0.0/0 --rule-action allow

# Block all inbound traffic except required ports (optional strict rule)
aws ec2 create-network-acl-entry --network-acl-id $NACL_ID --rule-number 200 --protocol -1 --port-range From=0,To=65535 --ingress --cidr-block 0.0.0.0/0 --rule-action deny

# Allow outbound all traffic (Modify as needed)
aws ec2 create-network-acl-entry --network-acl-id $NACL_ID --rule-number 300 --protocol -1 --port-range From=0,To=65535 --egress --cidr-block 0.0.0.0/0 --rule-action allow

echo "Security Groups & NACL Configuration Complete!"
