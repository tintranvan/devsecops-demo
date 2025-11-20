# Development Environment Configuration

environment    = "dev"
project_name   = "devsecops"
aws_region     = "us-east-1"

# VPC Configuration
vpc_cidr = "10.0.0.0/16"
private_subnet_cidrs = [
  "10.0.1.0/24",
  "10.0.2.0/24"
]
public_subnet_cidrs = [
  "10.0.101.0/24",
  "10.0.102.0/24"
]

# ECS Configuration - Dev uses more On-Demand for stability
ecs_capacity_providers = {
  fargate_weight      = 100
  fargate_spot_weight = 0
  fargate_base        = 1
}

# ALB Configuration
domain_name     = "dev-service-01.editforreal.com"
certificate_arn = "arn:aws:acm:us-east-1:647272350116:certificate/ef36ade1-979b-4369-9910-44fdb981b297"

# Security Configuration - Enable all for dev testing
enable_security_hub = true
enable_inspector    = true
enable_guardduty    = true

# Aurora Serverless Configuration - Minimal for dev
min_capacity = 0.5
max_capacity = 1

# Common Tags
common_tags = {
  Environment = "dev"
  Project     = "devsecops-assessment"
  Owner       = "DevSecOps-Team"
  CostCenter  = "Engineering"
  Purpose     = "Security-Assessment"
}
