# Core Infrastructure Outputs

# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.vpc.public_subnet_ids
}

# ECS Outputs
output "ecs_cluster_id" {
  description = "ID of the ECS cluster"
  value       = module.ecs_cluster.cluster_id
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs_cluster.cluster_name
}

output "ecs_security_group_id" {
  description = "ID of the ECS tasks security group"
  value       = aws_security_group.ecs_tasks.id
}

# ALB Outputs
output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = module.alb.alb_arn
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.alb.alb_dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = module.alb.alb_zone_id
}

output "alb_listener_arn" {
  description = "ARN of the ALB HTTPS listener"
  value       = module.alb.https_listener_arn
}

output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = module.alb.alb_security_group_id
}

# RDS Outputs
output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = module.rds.db_endpoint
  sensitive   = true
}

output "rds_port" {
  description = "RDS instance port"
  value       = module.rds.db_port
}

output "rds_database_name" {
  description = "RDS database name"
  value       = module.rds.db_name
}

output "rds_security_group_id" {
  description = "ID of the RDS security group"
  value       = module.rds.db_security_group_id
}

output "rds_cluster_identifier" {
  description = "RDS cluster identifier"
  value       = module.rds.cluster_identifier
}

output "rds_cluster_arn" {
  description = "RDS cluster ARN"
  value       = module.rds.cluster_arn
}

output "rds_master_user_secret_arn" {
  description = "RDS master user secret ARN"
  value       = module.rds.master_user_secret_arn
}

# SQS Outputs
output "sqs_queue_url" {
  description = "URL of the SQS queue"
  value       = module.sqs.queue_url
}

output "sqs_queue_arn" {
  description = "ARN of the SQS queue"
  value       = module.sqs.queue_arn
}

output "sqs_dlq_url" {
  description = "URL of the SQS dead letter queue"
  value       = module.sqs.dlq_url
}

# Security Hub Outputs
output "security_hub_processor_lambda_arn" {
  description = "ARN of the Security Hub processor Lambda function"
  value       = module.security_hub_processor.lambda_function_arn
}

output "security_hub_processor_sqs_url" {
  description = "URL of the Security Hub processor SQS queue"
  value       = module.security_hub_processor.sqs_queue_url
}

output "security_hub_account_id" {
  description = "Security Hub account ID"
  value       = module.security_hub.security_hub_account_id
}

output "security_findings_lambda_arn" {
  description = "ARN of the Security Findings Lambda function"
  value       = module.security_hub.security_findings_lambda_arn
}

# ECR Outputs
output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = aws_ecr_repository.java_app.repository_url
}

output "ecr_repository_arn" {
  description = "ARN of the ECR repository"
  value       = aws_ecr_repository.java_app.arn
}

# S3 Outputs
output "terraform_state_bucket" {
  description = "Name of the Terraform state bucket"
  value       = aws_s3_bucket.terraform_state.bucket
}

# Common Outputs
output "name_prefix" {
  description = "Name prefix used for resources"
  value       = local.name_prefix
}

output "environment" {
  description = "Environment name"
  value       = var.environment
}

output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}
