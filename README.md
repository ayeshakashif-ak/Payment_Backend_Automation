# Backend Payment Processing Automation

## Overview
This project automates the deployment of a high-performance, PCI DSS-compliant payment processing backend on AWS. The infrastructure is provisioned using AWS CLI and Bash scripts, with deployment automation via GitHub Actions.

## Features
- Custom VPC with public and private subnets for security and isolation.
- Custom AMI creation with pre-installed dependencies (Nginx & Node.js).
- EC2 Auto-Scaling with Security Groups and NACLs for controlled access.
- Application Load Balancer (ALB) for distributing traffic.
- Fully Automated Deployment via GitHub Actions.

## Architecture
### VPC Configuration
- **CIDR:** `10.0.0.0/16`
- **Public Subnets:** `10.0.1.0/24 (us-east-1a)`, `10.0.3.0/24 (us-east-1b)`
- **Private Subnets:** `10.0.2.0/24 (us-east-1a)`, `10.0.4.0/24 (us-east-1b)`
- **Internet Gateway** for public access
- **NAT Gateway** for private subnet internet access

### Security
- **Security Groups** for EC2 and ALB
- **NACLs** enforcing access restrictions

### Infrastructure Components
- Custom Amazon Machine Image (AMI) with pre-installed services.
- EC2 Instances in private subnets with auto-scaling.
- Application Load Balancer (ALB) distributing traffic.

## Deployment Steps

### 1. Set Up AWS Credentials
Before running any script, configure your AWS credentials:
```sh
aws configure
```
OR add them as GitHub Secrets:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

### 2. Build Custom AMI
```sh
bash scripts/build-ami.sh
```
This script:
- Installs Nginx and Node.js.
- Configures Nginx as a reverse proxy.
- Deploys a simple Node.js API returning a payment status response.
- Creates a new AMI.

### 3. Deploy Infrastructure
```sh
bash scripts/deploy.sh
```
This script provisions:
- A custom VPC with public and private subnets.
- EC2 instances using the custom AMI.
- Security Groups & NACLs.
- Application Load Balancer (ALB).

### 4. Test API Response
Once the deployment is complete, get the ALB DNS:
```sh
aws elbv2 describe-load-balancers --query 'LoadBalancers[0].DNSName' --output text
```
Then test the API:
```sh
curl http://<ALB-DNS>
```
Expected response:
```json
{
  "status": "Payment Processed",
  "timestamp": "<ISO-date>"
}
```

## Repository Structure
```
Backend-Payment-Processing-Automation/
│── scripts/
│   ├── build-ami.sh        # Creates the custom AMI
│   ├── deploy.sh           # Deploys the infrastructure
│── .github/workflows/
│   ├── deploy.yml          # GitHub Actions pipeline
│── README.md
```

## CI/CD Pipeline
The GitHub Actions pipeline automatically deploys the infrastructure:
- **Trigger:** Push to main branch.
- **Runner:** Ubuntu-based GitHub-hosted runner.
- **Steps:**
  - Configure AWS credentials.
  - Execute `build-ami.sh` to generate an AMI.
  - Execute `deploy.sh` to deploy the infrastructure.

## Validation Checklist
✔ VPC, Subnets, and NACLs Configured  
✔ Custom AMI Created Successfully  
✔ EC2 Instances Running & Connected to ALB  
✔ ALB Routing Traffic Properly  
✔ API Returns Valid JSON Response  

## Issues & Debugging
If any issues occur during deployment:
- Check logs:
  ```sh
  tail -f ec2-deployment.log
  ```
- Validate AWS resources:
  ```sh
  aws ec2 describe-instances --query 'Reservations[*].Instances[*].State.Name'
  ```
- Verify IAM permissions:
  ```sh
  aws iam list-instance-profiles
  
