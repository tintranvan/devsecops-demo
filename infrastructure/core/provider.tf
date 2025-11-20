# DevSecOps Assessment - Core Infrastructure
# Architecture: ALB → ECS Fargate → RDS + SQS with Security Hub Integration

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  backend "s3" {
    bucket         = "terraform-state-647272350116"
    region         = "us-east-1"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = merge(var.common_tags, {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = "DevSecOps"
      Assessment  = "DevSecOps-Pipeline"
    })
  }
}
