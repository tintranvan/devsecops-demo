# VPC Module Outputs

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

output "vpc_endpoints_security_group_id" {
  description = "ID of the VPC endpoints security group"
  value       = aws_security_group.vpc_endpoints.id
}

output "s3_endpoint_id" {
  description = "ID of the S3 VPC endpoint"
  value       = aws_vpc_endpoint.s3.id
}

output "ecr_endpoints" {
  description = "ECR VPC endpoint IDs"
  value = {
    dkr = aws_vpc_endpoint.ecr_dkr.id
    api = aws_vpc_endpoint.ecr_api.id
  }
}

output "aws_service_endpoints" {
  description = "AWS service VPC endpoint IDs"
  value = {
    logs           = aws_vpc_endpoint.logs.id
    monitoring     = aws_vpc_endpoint.monitoring.id
    secretsmanager = aws_vpc_endpoint.secretsmanager.id
    sqs            = aws_vpc_endpoint.sqs.id
    ecs            = aws_vpc_endpoint.ecs.id
    ecs_agent      = aws_vpc_endpoint.ecs_agent.id
    ecs_telemetry  = aws_vpc_endpoint.ecs_telemetry.id
    securityhub    = aws_vpc_endpoint.securityhub.id
    inspector      = aws_vpc_endpoint.inspector.id
    sts            = aws_vpc_endpoint.sts.id
    kms            = aws_vpc_endpoint.kms.id
  }
}
