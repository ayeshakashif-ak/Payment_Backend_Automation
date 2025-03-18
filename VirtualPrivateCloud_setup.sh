#!/bin/bash
set -e  # Exit immediately if a command fails

# Set AWS Region (change if needed)
AWS_REGION="us-east-1"

echo "Creating VPC..."
VPC_ID=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 --query "Vpc.VpcId" --output text --region $AWS_REGION)
aws ec2 create-tags --resources $VPC_ID --tags Key=Name,Value=PaymentProcessingVPC
echo "VPC Created: $VPC_ID"

echo "Creating Subnets..."
SUBNET_PUBLIC_A=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.1.0/24 --availability-zone us-east-1a --query "Subnet.SubnetId" --output text)
SUBNET_PUBLIC_B=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.3.0/24 --availability-zone us-east-1b --query "Subnet.SubnetId" --output text)
SUBNET_PRIVATE_A=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.2.0/24 --availability-zone us-east-1a --query "Subnet.SubnetId" --output text)
SUBNET_PRIVATE_B=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.4.0/24 --availability-zone us-east-1b --query "Subnet.SubnetId" --output text)
echo "Subnets Created: $SUBNET_PUBLIC_A, $SUBNET_PUBLIC_B, $SUBNET_PRIVATE_A, $SUBNET_PRIVATE_B"

echo "Creating Internet Gateway..."
IGW_ID=$(aws ec2 create-internet-gateway --query "InternetGateway.InternetGatewayId" --output text)
aws ec2 attach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID
echo "Internet Gateway Created: $IGW_ID"

echo "Creating Route Table for Public Subnets..."
RT_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --query "RouteTable.RouteTableId" --output text)
aws ec2 create-route --route-table-id $RT_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID
aws ec2 associate-route-table --route-table-id $RT_ID --subnet-id $SUBNET_PUBLIC_A
aws ec2 associate-route-table --route-table-id $RT_ID --subnet-id $SUBNET_PUBLIC_B
echo "Public Route Table Created: $RT_ID"

echo "Creating Security Groups..."
ALB_SG_ID=$(aws ec2 create-security-group --group-name ALB-SG --description "ALB Security Group" --vpc-id $VPC_ID --query "GroupId" --output text)
aws ec2 authorize-security-group-ingress --group-id $ALB_SG_ID --protocol tcp --port 80 --cidr 0.0.0.0/0
echo "ALB Security Group Created: $ALB_SG_ID"

EC2_SG_ID=$(aws ec2 create-security-group --group-name EC2-SG --description "EC2 Security Group" --vpc-id $VPC_ID --query "GroupId" --output text)
aws ec2 authorize-security-group-ingress --group-id $EC2_SG_ID --protocol tcp --port 80 --source-group $ALB_SG_ID
echo "EC2 Security Group Created: $EC2_SG_ID"

echo "Setting Up Network ACLs (Optional for PCI DSS)..."
NACL_ID=$(aws ec2 create-network-acl --vpc-id $VPC_ID --query "NetworkAcl.NetworkAclId" --output text)
aws ec2 create-network-acl-entry --network-acl-id $NACL_ID --rule-number 100 --protocol tcp --port-range From=80,To=80 --egress --cidr-block 0.0.0.0/0 --rule-action allow
aws ec2 create-network-acl-entry --network-acl-id $NACL_ID --rule-number 110 --protocol tcp --port-range From=443,To=443 --egress --cidr-block 0.0.0.0/0 --rule-action allow
echo "NACL Created: $NACL_ID"

echo "VPC & Networking Setup Complete!"
