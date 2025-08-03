# Setup Guide for AWS Network Firewall Automation

This guide provides step-by-step instructions for setting up and using the AWS Network Firewall automation project.

## Prerequisites

Before you begin, ensure you have the following installed:

- **AWS CLI** (v2.x or later)
- **Terraform** (v1.0 or later)
- **Python** (v3.9 or later)
- **UV** (Python package manager)
- **Git**

## Initial Setup

### 1. Clone the Repository

```bash
git clone https://github.com/nalindak/aws-network-routing-project.git
cd aws-network-routing-project
```

### 2. Configure AWS Credentials

Set up your AWS credentials using one of the following methods:

**Option A: AWS CLI Configuration**
```bash
aws configure
```

**Option B: Environment Variables**
```bash
export AWS_ACCESS_KEY_ID=your_access_key
export AWS_SECRET_ACCESS_KEY=your_secret_key
export AWS_DEFAULT_REGION=ap-southeast-4
```

### 3. Create GitHub OIDC Provider

In the AWS Console, create an OIDC provider for GitHub Actions:

1. Go to IAM → Identity providers
2. Click "Create provider"
3. Provider type: OpenID Connect
4. Provider URL: `https://token.actions.githubusercontent.com`
5. Audience: `sts.amazonaws.com`
6. Click "Add provider"

### 4. Bootstrap IAM Roles

Run the bootstrap script to create the necessary IAM roles:

```bash
chmod +x scripts/bootstrap-iam.sh
./scripts/bootstrap-iam.sh
```

This creates the `GitHubActionsNetworkFirewallDeployRole` with appropriate permissions.

### 5. Configure GitHub Repository Secrets

In your GitHub repository, add the following secrets:

- `AWS_ROLE_ARN`: `arn:aws:iam::563803513566:role/GitHubActionsNetworkFirewallDeployRole`

## Deployment Options

### Option 1: Automated Deployment (Recommended)

The project includes GitHub Actions workflows that automatically deploy infrastructure when you push to the main branch.

#### Terraform Deployment
- Triggers on changes to `terraform/` directory
- Automatically plans and applies changes
- Uses OIDC for secure AWS authentication

#### Route Table Updates
- Triggers on changes to `config/routes.yaml`
- Validates and applies route table changes
- Supports dry-run mode for testing

#### Firewall Rule Updates
- Triggers on changes to `config/firewall-rules.yaml`
- Updates Network Firewall policies and rules
- Includes validation and dry-run capabilities

### Option 2: Manual Deployment

For manual deployment, use the provided deployment script:

```bash
# Full deployment
./scripts/deploy.sh

# Initialize only
./scripts/deploy.sh init

# Plan Terraform changes
./scripts/deploy.sh plan

# Apply Terraform changes
./scripts/deploy.sh apply

# Update route tables only
./scripts/deploy.sh routes

# Update firewall rules only
./scripts/deploy.sh firewall

# Validate deployment
./scripts/deploy.sh validate
```

### Option 3: Step-by-Step Manual Deployment

#### Step 1: Initialize Terraform
```bash
cd terraform
terraform init
terraform validate
```

#### Step 2: Deploy Infrastructure
```bash
terraform plan -out=tfplan
terraform apply tfplan
```

#### Step 3: Setup Python Environment
```bash
cd python
uv sync
```

#### Step 4: Update Route Tables
```bash
uv run python route_manager.py --config ../config/routes.yaml --region ap-southeast-4
```

#### Step 5: Update Firewall Rules
```bash
uv run python firewall_manager.py --config ../config/firewall-rules.yaml --region ap-southeast-4
```

## Configuration

### Route Table Configuration

Edit `config/routes.yaml` to define your route table updates:

```yaml
route_tables:
  - table_id: "rtb-1234567890abcdef0"
    description: "Public route table"
    routes:
      - destination: "0.0.0.0/0"
        target: "igw-1234567890abcdef0"
        description: "Default route to internet gateway"
        target_type: "gateway"
```

### Firewall Rules Configuration

Edit `config/firewall-rules.yaml` to define your firewall policies:

```yaml
policies:
  - name: "network-firewall-policy"
    description: "Main firewall policy"
    rules:
      - name: "block-malicious-ips"
        priority: 100
        action: "DROP"
        source: "ANY"
        destination: "ANY"
        protocol: "ANY"
        description: "Block known malicious IPs"
```

## Monitoring and Logging

### Firewall Logs

Firewall logs are stored in S3 with the following structure:
- Flow logs: `s3://bucket-name/firewall-logs/`
- Alert logs: `s3://bucket-name/alert-logs/`

### CloudWatch Logs

Application logs are available in CloudWatch Logs under the log group `/aws/network-firewall/`.

### Monitoring Dashboard

Create a CloudWatch dashboard to monitor:
- Network Firewall metrics
- Route table changes
- Firewall rule updates

## Security Best Practices

### 1. Least Privilege Access

The IAM roles created by the bootstrap script follow the principle of least privilege:
- Only necessary permissions are granted
- Permissions are scoped to specific resources
- Regular access reviews are recommended

### 2. Network Security

- All firewall subnets are private
- Network ACLs are configured for additional security
- VPC Flow Logs are enabled for traffic monitoring

### 3. Data Protection

- S3 buckets are encrypted at rest
- All data in transit is encrypted
- Access logs are enabled for audit trails

## Troubleshooting

### Common Issues

#### 1. Terraform State Lock Issues
```bash
# If DynamoDB lock is stuck
aws dynamodb delete-item \
  --table-name terraform-state-lock \
  --key '{"LockID": {"S": "aws-network-firewall-terraform-state/network-firewall/terraform.tfstate"}}'
```

#### 2. Python Dependency Issues
```bash
cd python
uv sync --reinstall
```

#### 3. AWS Credentials Issues
```bash
aws sts get-caller-identity
```

#### 4. Network Firewall Status Issues
```bash
aws network-firewall describe-firewall --firewall-name network-firewall
```

### Debug Mode

Enable debug logging for Python scripts:
```bash
uv run python route_manager.py --config ../config/routes.yaml --verbose
```

## Maintenance

### Regular Tasks

1. **Update Dependencies**
   ```bash
   cd python
   uv sync --upgrade
   ```

2. **Review Firewall Rules**
   - Monitor firewall logs for blocked traffic
   - Update rules based on security requirements
   - Review and update malicious IP lists

3. **Backup Configuration**
   - Version control all configuration files
   - Regular backups of Terraform state
   - Document all customizations

### Cleanup

To destroy the infrastructure:
```bash
cd terraform
terraform destroy
```

## Support

For issues and questions:
1. Check the troubleshooting section
2. Review CloudWatch logs
3. Create an issue in the GitHub repository
4. Contact the development team

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is licensed under the MIT License. 