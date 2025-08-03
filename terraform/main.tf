# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name = "${var.environment}-vpc"
  })
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.environment}-igw"
  })
}

# Public Subnets
resource "aws_subnet" "public" {
  count             = length(var.public_subnets)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnets[count.index]
  availability_zone = var.availability_zones[count.index]

  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = "${var.environment}-public-subnet-${count.index + 1}"
    Type = "Public"
  })
}

# Private Subnets
resource "aws_subnet" "private" {
  count             = length(var.private_subnets)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(var.tags, {
    Name = "${var.environment}-private-subnet-${count.index + 1}"
    Type = "Private"
  })
}

# Firewall Subnets
resource "aws_subnet" "firewall" {
  count             = length(var.firewall_subnets)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.firewall_subnets[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(var.tags, {
    Name = "${var.environment}-firewall-subnet-${count.index + 1}"
    Type = "Firewall"
  })
}

# Route Tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(var.tags, {
    Name = "${var.environment}-public-rt"
  })
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.environment}-private-rt"
  })
}

# Route Table Associations
resource "aws_route_table_association" "public" {
  count          = length(var.public_subnets)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = length(var.private_subnets)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# Network Firewall Policy
resource "aws_networkfirewall_firewall_policy" "main" {
  name = var.firewall_policy_name

  firewall_policy {
    stateless_default_actions          = ["aws:forward_to_sfe"]
    stateless_fragment_default_actions = ["aws:forward_to_sfe"]

    stateful_rule_group_reference {
      resource_arn = aws_networkfirewall_rule_group.block_domains.arn
    }
  }

  tags = merge(var.tags, {
    Name = var.firewall_policy_name
  })
}

# Network Firewall
resource "aws_networkfirewall_firewall" "main" {
  name                = var.firewall_name
  firewall_policy_arn = aws_networkfirewall_firewall_policy.main.arn
  vpc_id              = aws_vpc.main.id

  dynamic "subnet_mapping" {
    for_each = aws_subnet.firewall
    content {
      subnet_id = subnet_mapping.value.id
    }
  }

  tags = merge(var.tags, {
    Name = var.firewall_name
  })
}

# Network Firewall Logging
resource "aws_networkfirewall_logging_configuration" "main" {
  firewall_arn = aws_networkfirewall_firewall.main.arn

  logging_configuration {
    log_destination_config {
      log_destination = {
        bucketName = aws_s3_bucket.firewall_logs.bucket
        prefix     = "firewall-logs/"
      }
      log_destination_type = "S3"
      log_type            = "FLOW"
    }

    log_destination_config {
      log_destination = {
        bucketName = aws_s3_bucket.firewall_logs.bucket
        prefix     = "alert-logs/"
      }
      log_destination_type = "S3"
      log_type            = "ALERT"
    }
  }
}

# S3 Bucket for Firewall Logs
resource "aws_s3_bucket" "firewall_logs" {
  bucket = "aws-network-firewall-logs-${random_string.bucket_suffix.result}"

  tags = merge(var.tags, {
    Name = "firewall-logs"
  })
}

resource "aws_s3_bucket_versioning" "firewall_logs" {
  bucket = aws_s3_bucket.firewall_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "firewall_logs" {
  bucket = aws_s3_bucket.firewall_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "firewall_logs" {
  bucket = aws_s3_bucket.firewall_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Random string for bucket naming
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

# Network Firewall Rule Groups
resource "aws_networkfirewall_rule_group" "block_domains" {
  capacity = 100
  name     = "block-malicious-domains"
  type     = "STATEFUL"
  rule_group {
    rules_source {
      rules_source_list {
        generated_rules_type = "DENYLIST"
        target_types        = ["HTTP_HOST", "TLS_SNI"]
        targets             = ["malicious-domain.com", "bad-site.org"]
      }
    }
  }

  tags = merge(var.tags, {
    Name = "block-malicious-domains"
  })
} 