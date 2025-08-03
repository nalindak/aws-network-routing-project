variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "ap-southeast-4"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnets" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnets" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "firewall_subnets" {
  description = "CIDR blocks for firewall subnets"
  type        = list(string)
  default     = ["10.0.20.0/24", "10.0.21.0/24"]
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["ap-southeast-4a", "ap-southeast-4b"]
}

variable "firewall_policy_name" {
  description = "Name for the Network Firewall policy"
  type        = string
  default     = "network-firewall-policy"
}

variable "firewall_name" {
  description = "Name for the Network Firewall"
  type        = string
  default     = "network-firewall"
}

variable "firewall_description" {
  description = "Description for the Network Firewall"
  type        = string
  default     = "AWS Network Firewall for traffic inspection"
}

variable "tags" {
  description = "Additional tags for resources for the firewall"
  type        = map(string)
  default     = {}
} 