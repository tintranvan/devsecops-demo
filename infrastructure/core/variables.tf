# Core Infrastructure Variables

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "devsecops"
}

# VPC Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}

# ECS Configuration
variable "ecs_capacity_providers" {
  description = "ECS capacity provider configuration"
  type = object({
    fargate_weight      = number
    fargate_spot_weight = number
    fargate_base        = number
  })
  default = {
    fargate_weight      = 100  # 100% On-Demand for security assessment
    fargate_spot_weight = 0    # 0% Spot for consistent security scanning
    fargate_base        = 1    # Minimum On-Demand instances
  }
}

# ALB Configuration
variable "domain_name" {
  description = "Domain name for SSL certificate"
  type        = string
  default     = "sample-app.example.com"
}

variable "certificate_arn" {
  description = "ARN of existing SSL certificate"
  type        = string
  default     = ""
}

# Security Configuration
variable "enable_security_hub" {
  description = "Enable AWS Security Hub"
  type        = bool
  default     = true
}

variable "enable_inspector" {
  description = "Enable AWS Inspector"
  type        = bool
  default     = true
}

variable "enable_guardduty" {
  description = "Enable AWS GuardDuty"
  type        = bool
  default     = true
}

# Database Configuration
variable "min_capacity" {
  description = "Minimum Aurora Serverless v2 capacity"
  type        = number
  default     = 0.5
}

variable "max_capacity" {
  description = "Maximum Aurora Serverless v2 capacity"
  type        = number
  default     = 2
}

# Tagging
variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}
