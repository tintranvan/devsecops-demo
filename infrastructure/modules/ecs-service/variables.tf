# ECS Service Module Variables

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "service_name" {
  description = "Name of the service"
  type        = string
}

variable "app_version" {
  description = "Version/timestamp for task definition versioning"
  type        = string
  default     = "latest"
}

variable "environment" {
  description = "Environment name"
  type        = string
}

# ECS Configuration
variable "cluster_id" {
  description = "ECS cluster ID"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs"
  type        = list(string)
}

# Container Configuration
variable "image_uri" {
  description = "Docker image URI"
  type        = string
}

variable "container_port" {
  description = "Container port"
  type        = number
  default     = 8080
}

variable "cpu" {
  description = "CPU units"
  type        = number
  default     = 256
}

variable "memory" {
  description = "Memory in MB"
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Desired number of tasks"
  type        = number
  default     = 1
}

variable "max_count" {
  description = "Maximum number of tasks"
  type        = number
  default     = 10
}

# Deployment Configuration
variable "minimum_healthy_percent" {
  description = "Lower limit on the number of running tasks during deployment (0-100)"
  type        = number
  default     = 50
}

variable "maximum_percent" {
  description = "Upper limit on the number of running tasks during deployment (100-200)"
  type        = number
  default     = 200
}

variable "health_check_grace_period" {
  description = "Seconds to ignore failing load balancer health checks on newly instantiated tasks"
  type        = number
  default     = 60
}

# Load Balancer
variable "alb_listener_arn" {
  description = "ALB listener ARN"
  type        = string
}

variable "alb_security_group_id" {
  description = "ALB security group ID"
  type        = string
}

variable "health_check_path" {
  description = "Health check path"
  type        = string
  default     = "/health"
}

# Security
variable "ecs_security_group_id" {
  description = "ECS security group ID for database access"
  type        = string
}

# Environment Variables
variable "environment_variables" {
  description = "Environment variables for the container"
  type        = map(string)
  default     = {}
}

variable "secrets" {
  description = "List of secrets to inject into container"
  type = list(object({
    name      = string
    valueFrom = string
  }))
  default = []
}

variable "secret_arns" {
  description = "List of secret ARNs for execution role permissions"
  type        = list(string)
  default     = []
}

variable "domain_name" {
  description = "Domain name for ALB listener rule"
  type        = string
  default     = ""
}

variable "priority" {
  description = "Priority for ALB listener rule"
  type        = number
  default     = 100
}

# Auto Scaling
variable "scaling_config" {
  description = "Auto scaling configuration"
  type = object({
    enabled              = bool
    cpu_target_value     = number
    memory_target_value  = number
  })
  default = {
    enabled = false
    cpu_target_value = 70
    memory_target_value = 80
  }
}

# IAM Permissions
variable "iam_permissions" {
  description = "IAM permissions for the task"
  type = list(object({
    service   = string
    actions   = list(string)
    resources = list(string)
  }))
  default = []
}

# AWS Services Integration
variable "rds_cluster_identifier" {
  description = "RDS cluster identifier"
  type        = string
  default     = ""
}

variable "sqs_queue_url" {
  description = "SQS queue URL"
  type        = string
  default     = ""
}

# Tags
variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}
