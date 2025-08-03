output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "firewall_subnet_ids" {
  description = "IDs of the firewall subnets"
  value       = aws_subnet.firewall[*].id
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

output "public_route_table_id" {
  description = "ID of the public route table"
  value       = aws_route_table.public.id
}

output "private_route_table_id" {
  description = "ID of the private route table"
  value       = aws_route_table.private.id
}

output "network_firewall_id" {
  description = "ID of the Network Firewall"
  value       = aws_networkfirewall_firewall.main.id
}

output "network_firewall_arn" {
  description = "ARN of the Network Firewall"
  value       = aws_networkfirewall_firewall.main.arn
}

output "network_firewall_status" {
  description = "Status of the Network Firewall"
  value       = aws_networkfirewall_firewall.main.firewall_status
}

output "firewall_policy_arn" {
  description = "ARN of the Network Firewall policy"
  value       = aws_networkfirewall_firewall_policy.main.arn
}

output "firewall_logs_bucket" {
  description = "S3 bucket for firewall logs"
  value       = aws_s3_bucket.firewall_logs.bucket
}

output "firewall_logs_bucket_arn" {
  description = "ARN of the S3 bucket for firewall logs"
  value       = aws_s3_bucket.firewall_logs.arn
}

output "availability_zones" {
  description = "List of availability zones used"
  value       = var.availability_zones
} 