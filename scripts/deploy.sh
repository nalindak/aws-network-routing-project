#!/bin/bash

# AWS Network Firewall Deployment Script
# This script orchestrates the deployment of AWS Network Firewall infrastructure

set -e

# Configuration
REGION="ap-southeast-4"
ENVIRONMENT="dev"
TERRAFORM_DIR="terraform"
PYTHON_DIR="python"
CONFIG_DIR="config"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if required tools are installed
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check if Terraform is installed
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform is not installed. Please install it first."
        exit 1
    fi
    
    # Check if Python is installed
    if ! command -v python3 &> /dev/null; then
        log_error "Python 3 is not installed. Please install it first."
        exit 1
    fi
    
    # Check if UV is installed
    if ! command -v uv &> /dev/null; then
        log_warning "UV is not installed. Installing UV..."
        curl -LsSf https://astral.sh/uv/install.sh | sh
        source ~/.bashrc
    fi
    
    log_success "All prerequisites are satisfied"
}

# Check AWS credentials
check_aws_credentials() {
    log_info "Checking AWS credentials..."
    
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials are not configured or invalid."
        log_info "Please configure your AWS credentials using:"
        log_info "  aws configure"
        log_info "  or"
        log_info "  export AWS_ACCESS_KEY_ID=your_access_key"
        log_info "  export AWS_SECRET_ACCESS_KEY=your_secret_key"
        log_info "  export AWS_DEFAULT_REGION=$REGION"
        exit 1
    fi
    
    log_success "AWS credentials are valid"
}

# Initialize Terraform
init_terraform() {
    log_info "Initializing Terraform..."
    cd $TERRAFORM_DIR
    
    # Initialize Terraform
    terraform init
    
    # Validate Terraform configuration
    terraform validate
    
    log_success "Terraform initialized successfully"
    cd ..
}

# Deploy Terraform infrastructure
deploy_terraform() {
    log_info "Deploying Terraform infrastructure..."
    cd $TERRAFORM_DIR
    
    # Plan Terraform deployment
    log_info "Planning Terraform deployment..."
    terraform plan -out=tfplan
    
    # Apply Terraform deployment
    log_info "Applying Terraform deployment..."
    terraform apply tfplan
    
    # Get outputs for Python scripts
    log_info "Getting Terraform outputs..."
    terraform output -json > ../terraform_outputs.json
    
    log_success "Terraform infrastructure deployed successfully"
    cd ..
}

# Setup Python environment
setup_python() {
    log_info "Setting up Python environment..."
    cd $PYTHON_DIR
    
    # Install dependencies using UV
    log_info "Installing Python dependencies..."
    uv sync
    
    log_success "Python environment setup complete"
    cd ..
}

# Update route tables
update_route_tables() {
    log_info "Updating route tables..."
    cd $PYTHON_DIR
    
    # Run route manager
    log_info "Running route manager..."
    uv run python route_manager.py --config ../$CONFIG_DIR/routes.yaml --region $REGION
    
    log_success "Route tables updated successfully"
    cd ..
}

# Update firewall rules
update_firewall_rules() {
    log_info "Updating firewall rules..."
    cd $PYTHON_DIR
    
    # Run firewall manager
    log_info "Running firewall manager..."
    uv run python firewall_manager.py --config ../$CONFIG_DIR/firewall-rules.yaml --region $REGION
    
    log_success "Firewall rules updated successfully"
    cd ..
}

# Validate deployment
validate_deployment() {
    log_info "Validating deployment..."
    
    # Check if Network Firewall is running
    log_info "Checking Network Firewall status..."
    FIREWALL_STATUS=$(aws network-firewall describe-firewall --firewall-name network-firewall --region $REGION --query 'Firewall.FirewallStatus.Status' --output text 2>/dev/null || echo "NOT_FOUND")
    
    if [ "$FIREWALL_STATUS" = "ACTIVE" ]; then
        log_success "Network Firewall is active"
    else
        log_warning "Network Firewall status: $FIREWALL_STATUS"
    fi
    
    # Check route tables
    log_info "Checking route tables..."
    cd $PYTHON_DIR
    uv run python route_manager.py --config ../$CONFIG_DIR/routes.yaml --region $REGION --validate-only
    cd ..
    
    log_success "Deployment validation complete"
}

# Show deployment summary
show_summary() {
    log_info "Deployment Summary:"
    echo "===================="
    echo "Region: $REGION"
    echo "Environment: $ENVIRONMENT"
    echo "Terraform State: S3 backend"
    echo "Network Firewall: Deployed"
    echo "Route Tables: Updated"
    echo "Firewall Rules: Applied"
    echo ""
    log_info "Next steps:"
    echo "1. Review the deployed infrastructure in AWS Console"
    echo "2. Test network connectivity"
    echo "3. Monitor firewall logs in S3"
    echo "4. Configure additional firewall rules as needed"
}

# Main deployment function
main() {
    log_info "Starting AWS Network Firewall deployment..."
    echo ""
    
    # Check prerequisites
    check_prerequisites
    echo ""
    
    # Check AWS credentials
    check_aws_credentials
    echo ""
    
    # Initialize Terraform
    init_terraform
    echo ""
    
    # Deploy Terraform infrastructure
    deploy_terraform
    echo ""
    
    # Setup Python environment
    setup_python
    echo ""
    
    # Update route tables
    update_route_tables
    echo ""
    
    # Update firewall rules
    update_firewall_rules
    echo ""
    
    # Validate deployment
    validate_deployment
    echo ""
    
    # Show summary
    show_summary
    echo ""
    
    log_success "Deployment completed successfully!"
}

# Parse command line arguments
case "${1:-}" in
    "init")
        check_prerequisites
        check_aws_credentials
        init_terraform
        setup_python
        ;;
    "plan")
        check_prerequisites
        check_aws_credentials
        cd $TERRAFORM_DIR
        terraform plan
        cd ..
        ;;
    "apply")
        check_prerequisites
        check_aws_credentials
        deploy_terraform
        ;;
    "routes")
        check_prerequisites
        check_aws_credentials
        setup_python
        update_route_tables
        ;;
    "firewall")
        check_prerequisites
        check_aws_credentials
        setup_python
        update_firewall_rules
        ;;
    "validate")
        check_prerequisites
        check_aws_credentials
        validate_deployment
        ;;
    "help"|"-h"|"--help")
        echo "AWS Network Firewall Deployment Script"
        echo ""
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  init      - Initialize Terraform and Python environment"
        echo "  plan      - Show Terraform plan"
        echo "  apply     - Deploy Terraform infrastructure"
        echo "  routes    - Update route tables"
        echo "  firewall  - Update firewall rules"
        echo "  validate  - Validate deployment"
        echo "  help      - Show this help message"
        echo ""
        echo "If no command is provided, the full deployment will be executed."
        ;;
    *)
        main
        ;;
esac 