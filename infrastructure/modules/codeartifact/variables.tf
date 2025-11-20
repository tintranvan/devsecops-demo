variable "name_prefix" {
  description = "Name prefix for resources"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for VPC endpoints"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for VPC endpoints"
  type        = list(string)
}

variable "vpc_endpoints_security_group_id" {
  description = "Security group ID for VPC endpoints"
  type        = string
}

variable "allowed_principals" {
  description = "List of AWS principals allowed to access CodeArtifact"
  type        = list(string)
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}
