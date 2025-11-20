# Production Environment Configuration

environment    = "prod"
project_name   = "devsecops"
aws_region     = "us-east-1"

# VPC Configuration
vpc_cidr = "10.2.0.0/16"
private_subnet_cidrs = [
  "10.2.1.0/24",
  "10.2.2.0/24",
  "10.2.3.0/24"
]
public_subnet_cidrs = [
  "10.2.101.0/24",
  "10.2.102.0/24",
  "10.2.103.0/24"
]

# ECS Configuration - Production uses On-Demand for maximum security
ecs_capacity_providers = {
  fargate_weight      = 100
  fargate_spot_weight = 0
  fargate_base        = 2
}

# ALB Configuration
domain_name     = "sample-app.example.com"
certificate_arn = ""  # Will be created or use existing

# Security Configuration - Maximum security for production
enable_security_hub = true
enable_inspector    = true
enable_guardduty    = true

# Database Configuration - Production grade
db_instance_class     = "db.t3.medium"
db_allocated_storage  = 100

# Common Tags
common_tags = {
  Environment = "prod"
  Project     = "devsecops-assessment"
  Owner       = "DevSecOps-Team"
  CostCenter  = "Engineering"
  Purpose     = "Security-Assessment"
  Compliance  = "SOC2-Required"
  Backup      = "Required"
  Monitoring  = "24x7"
}
