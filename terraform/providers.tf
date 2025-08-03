terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  backend "s3" {
    bucket         = "aws-network-firewall-terraform-state"
    key            = "network-firewall/terraform.tfstate"
    region         = "ap-southeast-4"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = "aws-network-firewall"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
} 