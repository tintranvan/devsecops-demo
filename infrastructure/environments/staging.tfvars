# Staging Environment Configuration

environment    = "staging"
project_name   = "devsecops"
aws_region     = "us-east-1"

# VPC Configuration
vpc_cidr = "10.1.0.0/16"
private_subnet_cidrs = [
  "10.1.1.0/24",
  "10.1.2.0/24"
]
public_subnet_cidrs = [
  "10.1.101.0/24",
  "10.1.102.0/24"
]

# ECS Configuration - Staging uses On-Demand for security validation
ecs_capacity_providers = {
  fargate_weight      = 100
  fargate_spot_weight = 0
  fargate_base        = 1
}

# ALB Configuration
domain_name     = "staging-sample-app.example.com"
certificate_arn = ""  # Will be created or use existing

# Security Configuration - Full security stack for staging
enable_security_hub = true
enable_inspector    = true
enable_guardduty    = true

# Database Configuration - Production-like for staging
db_instance_class     = "db.t3.small"
db_allocated_storage  = 50

# Common Tags
common_tags = {
  Environment = "staging"
  Project     = "devsecops-assessment"
  Owner       = "DevSecOps-Team"
  CostCenter  = "Engineering"
  Purpose     = "Security-Assessment"
  Compliance  = "Required"
}
