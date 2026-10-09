# Terraform Infrastructure Setup Guide

This directory contains the Infrastructure as Code (IaC) configuration for the e-commerce application using Terraform on AWS.

## Overview

The Terraform configuration provisions:
- **VPC (Virtual Private Cloud)** with public, private, and intra subnets across 3 availability zones
- **EKS (Elastic Kubernetes Service)** cluster with managed node groups
- **EC2 Instance** for Jenkins automation
- **Supporting services**: ArgoCD, RDS (PostgreSQL), secrets management, and pod identity

## Prerequisites

Before you begin, ensure you have:

1. **AWS Account** - with appropriate permissions to create VPC, EKS, EC2, RDS, and IAM resources
2. **AWS CLI** - installed and configured with credentials
3. **Terraform** - version 1.0 or higher
4. **kubectl** - for interacting with the Kubernetes cluster
5. **Helm** - for managing Kubernetes applications
6. **Git** - for version control

### AWS IAM Permissions

Ensure your AWS IAM user/role has permissions for:
- VPC and networking resources
- EKS cluster and node groups
- EC2 instances
- RDS (for PostgreSQL)
- IAM roles and policies
- Secrets Manager
- CloudWatch Logs
- S3 (for Terraform state backend)

## Directory Structure

```
terraform/
├── README.md                  # This file - setup instructions
├── versions.tf               # Terraform version and provider requirements
├── providers.tf              # AWS, Helm, and Kubernetes provider configurations
├── backend.tf                # S3 backend configuration
├── backend.hcl.example       # Example backend configuration
├── variables.tf              # Input variables for customization
├── vpc.tf                    # VPC and networking resources
├── eks.tf                    # EKS cluster and node group configuration
├── ec2.tf                    # EC2 instance for Jenkins
├── storage.tf                # Storage resources (RDS, secrets)
├── secrets.tf                # Secrets Manager configuration
├── pod-identity.tf           # EKS Pod Identity configuration
├── argocd.tf                 # ArgoCD Helm chart deployment
├── outputs.tf                # Output values after deployment
├── terraform.tfvars          # Variable values (customize for your environment)
├── bootstrap/                # Bootstrap configurations
├── .tflint.hcl              # TFLint linting configuration
└── terra-automate-key*       # SSH keys for EC2 automation
```

## Step-by-Step Infrastructure Creation

### Step 1: Prepare AWS Environment

```bash
# Set up AWS credentials
aws configure

# Verify connectivity
aws sts get-caller-identity

# Create S3 bucket for Terraform state (replace with unique bucket name)
aws s3api create-bucket \
  --bucket your-terraform-state-bucket \
  --region us-east-1

# Enable versioning on the state bucket
aws s3api put-bucket-versioning \
  --bucket your-terraform-state-bucket \
  --versioning-configuration Status=Enabled

# Enable server-side encryption
aws s3api put-bucket-encryption \
  --bucket your-terraform-state-bucket \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'
```

### Step 2: Clone and Setup Repository

```bash
# Clone the repository
git clone https://github.com/Bhushan-88/tws-e-commerce-app.git
cd tws-e-commerce-app/terraform

# Copy the backend configuration example
cp backend.hcl.example backend.hcl

# Update backend.hcl with your S3 bucket details
# Edit backend.hcl and replace the bucket name and region
```

### Step 3: Configure Variables

```bash
# Copy and customize terraform.tfvars
cp terraform.tfvars terraform.tfvars.backup

# Review and edit terraform.tfvars with your values
cat terraform.tfvars
```

**Key variables to review:**

```hcl
region                = "us-east-1"      # AWS region
cluster_name          = "devboard"       # EKS cluster name
kubernetes_version    = "1.34"           # EKS version
node_instance_type    = "c7i-flex.large" # Worker node type
node_desired_size     = 3                # Number of worker nodes
node_min_size         = 2                # Minimum nodes for auto-scaling
node_max_size         = 3                # Maximum nodes for auto-scaling
node_disk_size        = 30               # Root volume size in GiB
ec2_instance_type     = "t3.micro"       # Jenkins EC2 instance type
postgres_secret_name  = "devboard/postgres" # Secrets Manager secret name
enable_argocd         = true             # Install ArgoCD
```

### Step 4: Initialize Terraform

```bash
# Initialize Terraform working directory
# This downloads provider plugins and sets up the backend
terraform init -backend-config=backend.hcl

# Verify backend configuration
terraform init -backend-config=backend.hcl -upgrade
```

### Step 5: Validate Configuration

```bash
# Validate Terraform configuration syntax
terraform validate

# Format Terraform files (optional but recommended)
terraform fmt -recursive

# Run TFLint for best practices
tflint

# Create a plan to see what will be created
terraform plan -out=tfplan
```

### Step 6: Review the Plan

```bash
# Save the plan for review
terraform plan -out=tfplan

# View the plan in a human-readable format
terraform show tfplan

# Look for:
# - Correct number of resources (VPC, EKS, EC2, etc.)
# - Correct region and cluster name
# - Appropriate node sizing
```

### Step 7: Apply Infrastructure

```bash
# Apply the Terraform configuration (this may take 10-15 minutes)
terraform apply tfplan

# Or without plan file:
terraform apply

# When prompted, type 'yes' to confirm

# Save the state file securely
git add terraform.tfstate terraform.tfstate.backup 2>/dev/null || true
```

> ⏱️ **Note:** EKS cluster creation typically takes 10-15 minutes.

### Step 8: Retrieve Cluster Access

```bash
# Update kubeconfig to connect to the new cluster
aws eks update-kubeconfig \
  --region us-east-1 \
  --name devboard

# Verify cluster access
kubectl cluster-info
kubectl get nodes
kubectl get pods -A

# Test access to cluster
kubectl auth can-i get pods --as-group system:masters
```

### Step 9: Capture Outputs

```bash
# Display Terraform outputs
terraform output

# Retrieve specific values
terraform output -raw cluster_name
terraform output -raw cluster_endpoint
terraform output -raw cluster_arn

# Save outputs for reference
terraform output > outputs.txt
```

### Step 10: Configure Access Entries (Optional)

If you need to provide access to other IAM principals (e.g., intern users):

```bash
# Add intern IAM role to cluster access
terraform apply -var="intern_iam_principal_arn=arn:aws:iam::ACCOUNT_ID:role/InternRole"

# Verify access entry
kubectl describe accessentry --all-namespaces
```

## Configuration Details

### Network Architecture

```
VPC (10.0.0.0/16)
├── Public Subnets (10.0.1-3.0/24)
│   └── Internet Gateway, NAT Gateway
├── Private Subnets (10.0.4-6.0/24)
│   └── EKS Worker Nodes, Applications
└── Intra Subnets (10.0.7-9.0/24)
    └── EKS Control Plane, RDS
```

### EKS Cluster Features

- **Kubernetes Version**: Pinned version (default 1.34) for consistency
- **Addons**: CoreDNS, kube-proxy, VPC CNI, Pod Identity Agent, Metrics Server, EBS CSI Driver
- **Logging**: Audit and authenticator logs sent to CloudWatch (7-day retention)
- **Access Control**: Public and private endpoints enabled, IAM-based access control
- **Node Groups**: Single managed node group with auto-scaling (2-3 nodes)

### Storage Configuration

- **RDS PostgreSQL**: For application data persistence
- **Secrets Manager**: For secure credential storage
- **EBS Volumes**: For Kubernetes persistent volumes (encrypted)

## Troubleshooting

### Common Issues

#### 1. Terraform State Lock
```bash
# If Terraform is stuck waiting for a lock
terraform force-unlock <LOCK_ID>

# View lock information
aws s3api head-object --bucket your-bucket --key devboard/terraform.tfstate
```

#### 2. EC2 Key Pair Issues
```bash
# Verify the public key exists
ls -la terraform/terra-automate-key.pub

# If missing, create a new key pair
ssh-keygen -t rsa -b 4096 -f terraform/terra-automate-key
```

#### 3. EKS Cluster Not Accessible
```bash
# Verify security group rules
aws ec2 describe-security-groups --filters "Name=group-name,Values=*devboard*"

# Check cluster endpoint
aws eks describe-cluster --name devboard --query 'cluster.endpoint'

# Update kubeconfig
aws eks update-kubeconfig --name devboard --region us-east-1 --force
```

#### 4. Node Group Creation Fails
```bash
# Check node group events
aws eks describe-nodegroup --cluster-name devboard --nodegroup-name default

# Verify IAM role permissions
aws iam get-role --role-name devboard-eks-ManagedNodeGroup-Default
```

## Cost Management

The default configuration costs approximately:
- **VPC & NAT Gateway**: ~$33/month
- **EKS Cluster**: ~$75/month
- **EC2 Nodes (3x c7i-flex.large)**: ~$150/month
- **RDS PostgreSQL**: ~$30/month (varies by storage)

To reduce costs:
```bash
# Use t3.medium nodes (note: may not fit all workloads)
terraform apply -var="node_instance_type=t3.medium"

# Reduce node count to 2
terraform apply -var="node_desired_size=2"

# Disable ArgoCD if not needed
terraform apply -var="enable_argocd=false"
```

## Maintenance and Updates

### Updating Kubernetes Version
```bash
# Plan the upgrade
terraform plan -var="kubernetes_version=1.35"

# Apply the upgrade (takes 30-60 minutes)
terraform apply -var="kubernetes_version=1.35"
```

### Scaling Node Groups
```bash
# Increase nodes to 4
terraform apply -var="node_desired_size=4"

# Change instance type
terraform apply -var="node_instance_type=c7i-flex.xlarge"
```

### Backing Up State

```bash
# Backup current state
terraform state pull > backup-$(date +%Y%m%d).tfstate

# Store securely
gpg --symmetric backup-*.tfstate
```

## Destroying Infrastructure

> ⚠️ **WARNING**: This will delete all resources and data. Use with caution!

```bash
# Review what will be destroyed
terraform plan -destroy

# Destroy all resources
terraform destroy

# Force destroy if needed
terraform destroy -auto-approve

# Verify deletion in AWS Console
aws eks list-clusters --region us-east-1
```

## Security Best Practices

1. **State File Protection**
   - Store in S3 with encryption enabled
   - Enable versioning for recovery
   - Use IAM policies to restrict access

2. **Secrets Management**
   - Store sensitive values in AWS Secrets Manager
   - Never commit secrets to Git
   - Rotate credentials regularly

3. **Network Security**
   - Use private subnets for worker nodes
   - Implement network policies in Kubernetes
   - Enable VPC Flow Logs for monitoring

4. **IAM Access**
   - Use IAM roles for node groups
   - Implement least privilege principles
   - Audit access logs regularly

## Support and Documentation

- **Terraform AWS Provider**: https://registry.terraform.io/providers/hashicorp/aws/latest
- **EKS Module**: https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest
- **VPC Module**: https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest
- **AWS Documentation**: https://docs.aws.amazon.com/eks/

## Next Steps

After infrastructure is created:

1. Install and configure ArgoCD for GitOps
2. Set up cluster monitoring with Prometheus and Grafana
3. Configure application deployments
4. Set up CI/CD pipelines
5. Implement backup and disaster recovery strategies
6. Configure autoscaling policies
7. Set up network policies and security policies

## Contributing

When modifying Terraform configurations:

1. Run `terraform fmt` to format code
2. Run `terraform validate` to check syntax
3. Run `tflint` to check for best practices
4. Create a plan file for review before applying
5. Document all changes in commit messages

---

**Last Updated**: 2026-10-09
**Terraform Version**: >= 1.0
**AWS Provider Version**: >= 5.0
