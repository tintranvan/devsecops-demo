# Local values
locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# VPC Module
module "vpc" {
  source = "../modules/vpc"

  name_prefix            = local.name_prefix
  aws_region            = var.aws_region
  vpc_cidr              = var.vpc_cidr
  private_subnet_cidrs  = var.private_subnet_cidrs
  public_subnet_cidrs   = var.public_subnet_cidrs
  common_tags           = var.common_tags
}

# ECS Cluster Module
module "ecs_cluster" {
  source = "../modules/ecs-cluster"

  cluster_name            = "${local.name_prefix}-cluster"
  fargate_weight         = var.ecs_capacity_providers.fargate_weight
  fargate_spot_weight    = var.ecs_capacity_providers.fargate_spot_weight
  fargate_base           = var.ecs_capacity_providers.fargate_base
  log_retention_days     = 30
  common_tags            = var.common_tags
}

# Application Load Balancer Module
module "alb" {
  source = "../modules/alb"

  name_prefix         = local.name_prefix
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnet_ids
  certificate_arn    = var.certificate_arn
  domain_name        = var.domain_name
  common_tags        = var.common_tags
}

# ECS Security Group for database access
resource "aws_security_group" "ecs_tasks" {
  name_prefix = "${local.name_prefix}-ecs-tasks-"
  vpc_id      = module.vpc.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-ecs-tasks-sg"
  })
}

# RDS Database Module
module "rds" {
  source = "../modules/rds"

  name_prefix           = local.name_prefix
  vpc_id               = module.vpc.vpc_id
  private_subnet_ids   = module.vpc.private_subnet_ids
  min_capacity         = var.min_capacity
  max_capacity         = var.max_capacity
  allowed_security_groups = [aws_security_group.ecs_tasks.id]
  common_tags          = var.common_tags
}

# SQS Queue Module
module "sqs" {
  source = "../modules/sqs-queue"

  name_prefix = local.name_prefix
  queue_name  = "java-app-queue"
  common_tags = var.common_tags
}

# Security Hub Module
module "security_hub" {
  source = "../modules/security-hub"

  name_prefix        = local.name_prefix
  enable_security_hub = var.enable_security_hub
  enable_inspector   = var.enable_inspector
  enable_guardduty   = var.enable_guardduty
  common_tags        = var.common_tags
}

# CodeArtifact Module
module "codeartifact" {
  source = "../modules/codeartifact"

  name_prefix                      = local.name_prefix
  aws_region                      = var.aws_region
  vpc_id                          = module.vpc.vpc_id
  private_subnet_ids              = module.vpc.private_subnet_ids
  vpc_endpoints_security_group_id = module.vpc.vpc_endpoints_security_group_id
  allowed_principals              = [
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
  ]
  common_tags = var.common_tags
}

# Data source for current AWS account
data "aws_caller_identity" "current" {}

# S3 Bucket for Terraform State (if not exists)
resource "aws_s3_bucket" "terraform_state" {
  bucket = "devsecops-terraform-state-647272350116"

  tags = merge(var.common_tags, {
    Name        = "DevSecOps Terraform State Bucket"
    Environment = var.environment
  })
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Shared ECR Repository for Java Application
resource "aws_ecr_repository" "java_app" {
  name                 = "${local.name_prefix}-java-app"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-java-app-ecr"
  })
}

resource "aws_ecr_lifecycle_policy" "java_app" {
  repository = aws_ecr_repository.java_app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 production images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["prod"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Keep last 5 staging images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["staging"]
          countType     = "imageCountMoreThan"
          countNumber   = 5
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 3
        description  = "Keep last 3 dev images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["dev"]
          countType     = "imageCountMoreThan"
          countNumber   = 3
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 4
        description  = "Delete untagged images older than 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# Security Hub Processor Module
module "security_hub_processor" {
  source = "../modules/security-hub-processor"
}
