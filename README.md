# AWS Network Firewall Automation Project

This repository provides automated provisioning and management of AWS Network Firewall using Terraform, with route table updates managed via YAML configuration and Python automation.

## Features

- **Terraform Infrastructure**: Automated provisioning of AWS Network Firewall
- **Route Table Management**: YAML-based configuration for route table updates
- **Python Automation**: UV-based Python scripts for applying changes
- **GitHub Actions**: Automated CI/CD pipeline with OIDC authentication
- **IAM Role Management**: Bootstrap script for creating necessary IAM roles

## Project Structure

```
aws-network-routing-project/
├── terraform/                 # Terraform infrastructure code
│   ├── main.tf               # Main Terraform configuration
│   ├── variables.tf          # Variable definitions
│   ├── outputs.tf            # Output definitions
│   └── providers.tf          # Provider configuration
├── python/                   # Python automation scripts
│   ├── pyproject.toml        # UV project configuration
│   ├── requirements.txt      # Python dependencies
│   ├── route_manager.py      # Route table management script
│   └── firewall_manager.py   # Firewall management utilities
├── config/                   # Configuration files
│   ├── routes.yaml           # Route table configuration
│   └── firewall-rules.yaml   # Firewall rules configuration
├── scripts/                  # Utility scripts
│   ├── bootstrap-iam.sh      # IAM role creation script
│   └── deploy.sh             # Deployment script
├── .github/                  # GitHub Actions workflows
│   └── workflows/
│       ├── terraform.yml     # Terraform deployment workflow
│       └── route-update.yml  # Route table update workflow
└── docs/                     # Documentation
    └── setup.md              # Setup instructions
```

## Quick Start

1. **Clone the repository**:
   ```bash
   git clone https://github.com/nalindak/aws-network-routing-project.git
   cd aws-network-routing-project
   ```

2. **Bootstrap IAM roles**:
   ```bash
   chmod +x scripts/bootstrap-iam.sh
   ./scripts/bootstrap-iam.sh
   ```

3. **Configure your AWS credentials**:
   ```bash
   export AWS_ACCESS_KEY_ID=your_access_key
   export AWS_SECRET_ACCESS_KEY=your_secret_key
   export AWS_DEFAULT_REGION=ap-southeast-4
   ```

4. **Initialize Terraform**:
   ```bash
   cd terraform
   terraform init
   terraform plan
   terraform apply
   ```

5. **Update route tables**:
   ```bash
   cd python
   uv run python route_manager.py --config ../config/routes.yaml
   ```

## GitHub Actions

The repository includes automated workflows for:
- **Terraform Deployment**: Automated infrastructure provisioning
- **Route Table Updates**: Automated route table management
- **Security Scanning**: Automated security checks

## Configuration

### Route Table Configuration (`config/routes.yaml`)

```yaml
route_tables:
  - table_id: rtb-1234567890abcdef0
    routes:
      - destination: 0.0.0.0/0
        target: igw-1234567890abcdef0
        description: "Default route to internet gateway"
      - destination: 10.0.0.0/16
        target: vpc-peering-connection
        description: "Route to peered VPC"
```

### Firewall Rules Configuration (`config/firewall-rules.yaml`)

```yaml
firewall_rules:
  - name: "block-malicious-ips"
    priority: 100
    action: "DROP"
    source: "0.0.0.0/0"
    destination: "0.0.0.0/0"
    protocol: "ANY"
    description: "Block known malicious IPs"
```

## Python Automation

The Python scripts use UV for dependency management and provide:
- Route table updates
- Firewall rule management
- Configuration validation
- Change tracking and rollback

## Security

- OIDC-based authentication for GitHub Actions
- Least privilege IAM roles
- Encrypted state storage
- Audit logging for all changes

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

MIT License - see LICENSE file for details.
