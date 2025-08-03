#!/bin/bash

# Bootstrap script to create initial IAM roles for GitHub Actions
# This script creates the minimal IAM roles needed for GitHub Actions to work

set -e

# Configuration
ACCOUNT_ID="563803513566"
REGION="ap-southeast-4"
GITHUB_REPO="nalindak/aws-network-routing-project"

echo "Creating initial IAM roles for GitHub Actions..."

# Note: OIDC provider should be created manually in AWS Console
echo "Note: Please ensure GitHub OIDC provider is created manually in AWS Console"
echo "Provider URL: https://token.actions.githubusercontent.com"
echo "Client ID: sts.amazonaws.com"

# Create GitHub Actions Network Firewall Deploy Role
echo "Creating GitHubActionsNetworkFirewallDeployRole..."

aws iam create-role \
    --role-name GitHubActionsNetworkFirewallDeployRole \
    --assume-role-policy-document '{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Action": "sts:AssumeRoleWithWebIdentity",
                "Effect": "Allow",
                "Principal": {
                    "Federated": "arn:aws:iam::'$ACCOUNT_ID':oidc-provider/token.actions.githubusercontent.com"
                },
                "Condition": {
                    "StringEquals": {
                        "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
                    },
                    "StringLike": {
                        "token.actions.githubusercontent.com:sub": "repo:'$GITHUB_REPO':ref:refs/heads/main"
                    }
                }
            }
        ]
    }' \
    --region $REGION

# Create policy for GitHub Actions Network Firewall deployment
echo "Creating policy for GitHub Actions Network Firewall deployment..."

aws iam put-role-policy \
    --role-name GitHubActionsNetworkFirewallDeployRole \
    --policy-name NetworkFirewallDeployPolicy \
    --policy-document '{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": [
                    "network-firewall:*",
                    "ec2:*",
                    "iam:CreateRole",
                    "iam:DeleteRole",
                    "iam:GetRole",
                    "iam:PutRolePolicy",
                    "iam:DeleteRolePolicy",
                    "iam:AttachRolePolicy",
                    "iam:DetachRolePolicy",
                    "iam:TagRole",
                    "iam:UntagRole",
                    "iam:PassRole"
                ],
                "Resource": "*"
            }
        ]
    }' \
    --region $REGION

# Create policy for GitHub Actions Terraform management
echo "Creating policy for GitHub Actions Terraform management..."

aws iam put-role-policy \
    --role-name GitHubActionsNetworkFirewallDeployRole \
    --policy-name TerraformPolicy \
    --policy-document '{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": [
                    "dynamodb:*",
                    "events:*",
                    "secretsmanager:*",
                    "s3:*",
                    "logs:*",
                    "cloudwatch:*",
                    "kms:*"
                ],
                "Resource": "*"
            }
        ]
    }' \
    --region $REGION

# Create policy for GitHub Actions Route Table management
echo "Creating policy for GitHub Actions Route Table management..."

aws iam put-role-policy \
    --role-name GitHubActionsNetworkFirewallDeployRole \
    --policy-name RouteTablePolicy \
    --policy-document '{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": [
                    "ec2:CreateRoute",
                    "ec2:DeleteRoute",
                    "ec2:ReplaceRoute",
                    "ec2:DescribeRouteTables",
                    "ec2:DescribeRoutes",
                    "ec2:DescribeVpcs",
                    "ec2:DescribeSubnets",
                    "ec2:DescribeInternetGateways",
                    "ec2:DescribeNatGateways",
                    "ec2:DescribeVpcPeeringConnections",
                    "ec2:DescribeNetworkInterfaces"
                ],
                "Resource": "*"
            }
        ]
    }' \
    --region $REGION

# Create policy for GitHub Actions VPC management
echo "Creating policy for GitHub Actions VPC management..."

aws iam put-role-policy \
    --role-name GitHubActionsNetworkFirewallDeployRole \
    --policy-name VPCManagementPolicy \
    --policy-document '{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": [
                    "ec2:CreateVpc",
                    "ec2:DeleteVpc",
                    "ec2:DescribeVpcs",
                    "ec2:CreateSubnet",
                    "ec2:DeleteSubnet",
                    "ec2:DescribeSubnets",
                    "ec2:CreateRouteTable",
                    "ec2:DeleteRouteTable",
                    "ec2:DescribeRouteTables",
                    "ec2:CreateInternetGateway",
                    "ec2:DeleteInternetGateway",
                    "ec2:DescribeInternetGateways",
                    "ec2:AttachInternetGateway",
                    "ec2:DetachInternetGateway",
                    "ec2:CreateNatGateway",
                    "ec2:DeleteNatGateway",
                    "ec2:DescribeNatGateways",
                    "ec2:AssociateRouteTable",
                    "ec2:DisassociateRouteTable",
                    "ec2:CreateTags",
                    "ec2:DeleteTags",
                    "ec2:DescribeTags"
                ],
                "Resource": "*"
            }
        ]
    }' \
    --region $REGION

# Create policy for GitHub Actions S3 management (for Terraform state and logs)
echo "Creating policy for GitHub Actions S3 management..."

aws iam put-role-policy \
    --role-name GitHubActionsNetworkFirewallDeployRole \
    --policy-name S3ManagementPolicy \
    --policy-document '{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": [
                    "s3:CreateBucket",
                    "s3:DeleteBucket",
                    "s3:GetBucketLocation",
                    "s3:GetBucketVersioning",
                    "s3:PutBucketVersioning",
                    "s3:GetBucketEncryption",
                    "s3:PutBucketEncryption",
                    "s3:GetBucketPublicAccessBlock",
                    "s3:PutBucketPublicAccessBlock",
                    "s3:GetObject",
                    "s3:PutObject",
                    "s3:DeleteObject",
                    "s3:ListBucket",
                    "s3:GetBucketPolicy",
                    "s3:PutBucketPolicy",
                    "s3:DeleteBucketPolicy"
                ],
                "Resource": [
                    "arn:aws:s3:::aws-network-firewall-*",
                    "arn:aws:s3:::aws-network-firewall-*/*"
                ]
            }
        ]
    }' \
    --region $REGION

# Create policy for GitHub Actions CloudWatch Logs
echo "Creating policy for GitHub Actions CloudWatch Logs..."

aws iam put-role-policy \
    --role-name GitHubActionsNetworkFirewallDeployRole \
    --policy-name CloudWatchLogsPolicy \
    --policy-document '{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": [
                    "logs:CreateLogGroup",
                    "logs:CreateLogStream",
                    "logs:PutLogEvents",
                    "logs:DescribeLogGroups",
                    "logs:DescribeLogStreams",
                    "logs:ListTagsForResource",
                    "logs:TagResource",
                    "logs:UntagResource",
                    "logs:DeleteLogGroup",
                    "logs:PutRetentionPolicy"
                ],
                "Resource": "*"
            }
        ]
    }' \
    --region $REGION

echo "✅ Initial IAM roles created successfully!"
echo "GitHubActionsNetworkFirewallDeployRole: arn:aws:iam::$ACCOUNT_ID:role/GitHubActionsNetworkFirewallDeployRole"
echo ""
echo "Now you can run GitHub Actions workflows that will use these roles."
echo "Network Firewall infrastructure will be created via Terraform."
echo ""
echo "Next steps:"
echo "1. Ensure GitHub OIDC provider is configured in AWS Console"
echo "2. Add the role ARN to your GitHub repository secrets as AWS_ROLE_ARN"
echo "3. Configure GitHub Actions workflows to use OIDC authentication" 