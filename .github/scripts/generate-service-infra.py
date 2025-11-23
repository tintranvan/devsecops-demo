#!/usr/bin/env python3
"""
Service Infrastructure Generator

Generates Terraform for ECS services based on service.yaml template
Similar to flodesk-infra/scripts/generate-service-infra.py
"""

import yaml
import os
import sys
import json

# Load configuration from environment
AWS_ACCOUNT_ID = os.getenv('AWS_ACCOUNT_ID', '647272350116')
AWS_REGION = os.getenv('AWS_REGION', 'us-east-1')
PROJECT_NAME = os.getenv('PROJECT_NAME', 'devsecops')

def get_load_balancer_config(service_config, environment):
    """Get load balancer configuration from service config"""
    # Check environment-specific config first
    env_config = service_config.get('environments', {}).get(environment, {})
    env_lb_config = env_config.get('load_balancer', {})
    
    # Check base config
    base_lb_config = service_config.get('load_balancer', {})
    
    return {
        'health_check_path': env_lb_config.get('health_check_path', base_lb_config.get('health_check_path', '/')),
        'domain_name': env_lb_config.get('domain_name', base_lb_config.get('domain_name', '')),
        'priority': env_lb_config.get('priority', base_lb_config.get('priority', 100))
    }

def get_health_check_path(service_config, environment):
    """Get health check path from service config"""
    # Check environment-specific config first
    env_config = service_config.get('environments', {}).get(environment, {})
    env_lb_config = env_config.get('load_balancer', {})
    
    # Check base config
    base_lb_config = service_config.get('load_balancer', {})
    
    # Return environment-specific or base health check path, default to "/"
    return env_lb_config.get('health_check_path', base_lb_config.get('health_check_path', '/'))

def get_deployment_config(service_config, environment):
    """Get deployment configuration from service config"""
    deployment = service_config.get('deployment', {})
    
    # Parse health_check_grace_period to seconds
    grace_period = deployment.get('health_check_grace_period', '60s')
    if isinstance(grace_period, str):
        grace_period_seconds = int(grace_period.replace('s', ''))
    else:
        grace_period_seconds = grace_period
    
    return {
        'minimum_healthy_percent': deployment.get('minimum_healthy_percent', 50),
        'maximum_percent': deployment.get('maximum_percent', 200),
        'health_check_grace_period': grace_period_seconds
    }

def generate_ecs_service_tf(service_config, environment, version=None):
    """Generate Terraform for ECS service using modules"""
    name = service_config['name']
    
    # Get environment-specific config
    env_config = service_config.get('environments', {}).get(environment, {})
    base_resources = service_config.get('resources', {})
    env_resources = env_config.get('resources', {})
    
    # Merge resources
    memory = env_resources.get('memory', base_resources.get('memory', 512))
    cpu = env_resources.get('cpu', base_resources.get('cpu', 256))
    desired_count = env_resources.get('desired_count', base_resources.get('desired_count', 1))
    max_count = env_resources.get('max_count', base_resources.get('max_count', 10))
    
    # Get deployment configuration
    deployment_config = get_deployment_config(service_config, environment)
    
    # Environment variables
    base_env_vars = service_config.get('environment_variables', {})
    env_env_vars = env_config.get('environment_variables', {})
    environment_variables = {**base_env_vars, **env_env_vars}
    
    tf_content = f'''# Generated Terraform for {name} using modules
terraform {{
  backend "s3" {{
    bucket = "terraform-state-{AWS_ACCOUNT_ID}"
    key    = "{environment}/services/{name}/terraform.tfstate"
    region = "{AWS_REGION}"
    encrypt = true
  }}
}}

provider "aws" {{
  region = "{AWS_REGION}"
}}

# Data sources for core infrastructure
data "terraform_remote_state" "core" {{
  backend = "s3"
  config = {{
    bucket = "terraform-state-{AWS_ACCOUNT_ID}"
    key    = "{environment}/core/terraform.tfstate"
    region = "{AWS_REGION}"
  }}
}}

# Secrets Manager
resource "random_password" "secrets" {{
  for_each = toset({generate_secret_names(service_config)})
  length   = 32
  special  = true
}}

resource "aws_secretsmanager_secret" "service_secret" {{
  name = "${{var.name_prefix}}-${{var.service_name}}"
  
  tags = var.common_tags
}}

resource "aws_secretsmanager_secret_version" "service_secret" {{
  secret_id = aws_secretsmanager_secret.service_secret.id
  secret_string = jsonencode({{
{generate_secret_json(service_config)}
  }})
}}

# ECS Service Module
module "ecs_service" {{
  source = "../../infrastructure/modules/ecs-service"

  # Basic Configuration
  name_prefix    = "{PROJECT_NAME}-{environment}"
  service_name   = "{name}"
  environment    = "{environment}"
  
  # ECS Configuration
  cluster_id           = data.terraform_remote_state.core.outputs.ecs_cluster_id
  vpc_id              = data.terraform_remote_state.core.outputs.vpc_id
  private_subnet_ids  = data.terraform_remote_state.core.outputs.private_subnet_ids
  
  # Container Configuration
  image_uri           = var.image_uri
  container_port      = 8080
  cpu                 = {cpu}
  memory              = {memory}
  desired_count       = {desired_count}
  max_count          = {max_count}
  
  # Deployment Configuration (for fast deployment)
  minimum_healthy_percent    = {deployment_config['minimum_healthy_percent']}
  maximum_percent            = {deployment_config['maximum_percent']}
  health_check_grace_period  = {deployment_config['health_check_grace_period']}
  
  # Load Balancer
  alb_listener_arn       = data.terraform_remote_state.core.outputs.alb_listener_arn
  alb_security_group_id  = data.terraform_remote_state.core.outputs.alb_security_group_id
  health_check_path      = "{get_load_balancer_config(service_config, environment)['health_check_path']}"
  domain_name           = "{get_load_balancer_config(service_config, environment)['domain_name']}"
  priority              = {get_load_balancer_config(service_config, environment)['priority']}
  
  # Security
  ecs_security_group_id = data.terraform_remote_state.core.outputs.ecs_security_group_id
  
  # Environment Variables
  environment_variables = {{
{generate_environment_variables_map(environment_variables, service_config, environment)}
  }}
  
  # Auto Scaling
  scaling_config = {{
{generate_scaling_config(service_config)}
  }}
  
  # IAM Permissions
  iam_permissions = [
{generate_iam_permissions(service_config)}
  ]
  
  # AWS Services Integration
  sqs_queue_url         = module.sqs.queue_url
  
  # Secrets
  secrets = [
{generate_secrets_list(service_config)}
  ]
  
  # Secret ARNs for execution role
  secret_arns = ["${{aws_secretsmanager_secret.service_secret.arn}}"]
  
  # Tags
  common_tags = {{
    Environment = "{environment}"
    Service     = "{name}"
    ManagedBy   = "Terraform"
    Project     = "devsecops-assessment"
  }}
}}

# SQS Queue Module for this service
module "sqs" {{
  source = "../../infrastructure/modules/sqs-queue"

  name_prefix = "{PROJECT_NAME}-{environment}"
  queue_name  = "{name}-service-queue"
  
  # Tags
  common_tags = {{
    Environment = "{environment}"
    Service     = "{name}"
    ManagedBy   = "Terraform"
    Project     = "devsecops-assessment"
  }}
}}

# Variables
variable "name_prefix" {{
  description = "Name prefix for resources"
  type        = string
  default     = "{PROJECT_NAME}-{environment}"
}}

variable "service_name" {{
  description = "Name of the service"
  type        = string
  default     = "{name}"
}}

variable "common_tags" {{
  description = "Common tags for all resources"
  type        = map(string)
  default = {{
    Environment = "{environment}"
    Service     = "{name}"
    ManagedBy   = "Terraform"
    Project     = "devsecops-assessment"
  }}
}}

variable "image_uri" {{
  description = "Docker image URI"
  type        = string
  default     = "{AWS_ACCOUNT_ID}.dkr.ecr.{AWS_REGION}.amazonaws.com/{PROJECT_NAME}-{environment}-java-app:{version or 'latest'}"
}}

# Outputs
output "service_name" {{
  description = "Name of the ECS service"
  value       = module.ecs_service.service_name
}}

output "service_arn" {{
  description = "ARN of the ECS service"
  value       = module.ecs_service.service_arn
}}

output "task_definition_arn" {{
  description = "ARN of the task definition"
  value       = module.ecs_service.task_definition_arn
}}

output "security_group_id" {{
  description = "Security group ID for the service"
  value       = module.ecs_service.security_group_id
}}

output "sqs_queue_url" {{
  description = "SQS queue URL for the service"
  value       = module.sqs.queue_url
}}

output "sqs_queue_arn" {{
  description = "SQS queue ARN for the service"
  value       = module.sqs.queue_arn
}}
'''
    
    return tf_content

def generate_environment_variables_map(env_vars, service_config, environment):
    """Generate environment variables as Terraform map"""
    variables = []
    
    # Add service-specific environment variables
    for key, value in env_vars.items():
        variables.append(f'    {key} = "{value}"')
    
    # Add AWS service configurations
    aws_services = service_config.get('aws_services', {})
    
    if 'sqs' in aws_services:
        variables.append(f'    SQS_QUEUE_URL = "${{module.sqs.queue_url}}"')
    
    variables.extend([
        f'    AWS_REGION = "us-east-1"',
        f'    ENVIRONMENT = "{environment}"'
    ])
    
    return '\n'.join(variables)

def generate_scaling_config(service_config):
    """Generate auto-scaling configuration"""
    scaling_config = service_config.get('scaling', {})
    metrics = scaling_config.get('metrics', [])
    
    if not metrics:
        return '    enabled = false'
    
    config_lines = ['    enabled = true']
    
    for metric in metrics:
        metric_name = metric['name']
        target_value = metric['target_value']
        
        if metric_name == 'cpu_utilization':
            config_lines.append(f'    cpu_target_value = {target_value}')
        elif metric_name == 'memory_utilization':
            config_lines.append(f'    memory_target_value = {target_value}')
    
    return '\n'.join(config_lines)

def generate_secret_names(service_config):
    """Generate list of secret names from service config"""
    secret_vars = service_config.get('secret_variables', [])
    # Format as Terraform list instead of JSON
    return '[' + ', '.join([f'"{name}"' for name in secret_vars]) + ']'

def generate_secret_json(service_config):
    """Generate JSON content for the secret"""
    secret_vars = service_config.get('secret_variables', [])
    secrets = []
    for secret_name in secret_vars:
        secrets.append(f'    {secret_name} = random_password.secrets["{secret_name}"].result')
    return '\n'.join(secrets)

def generate_secrets_list(service_config):
    """Generate secrets list for ECS task definition"""
    secret_vars = service_config.get('secret_variables', [])
    
    secrets = []
    for secret_name in secret_vars:
        secret_block = f'''    {{
      name      = "{secret_name}"
      valueFrom = "${{aws_secretsmanager_secret.service_secret.arn}}:{secret_name}::"
    }}'''
        secrets.append(secret_block)
    
    return ',\n'.join(secrets)

def generate_iam_permissions(service_config):
    """Generate IAM permissions list"""
    permissions = []
    
    # Add SQS permissions
    aws_services = service_config.get('aws_services', {})
    if 'sqs' in aws_services:
        perm_block = f'''    {{
      service   = "sqs"
      actions   = ["sqs:SendMessage", "sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
      resources = ["${{module.sqs.queue_arn}}"]
    }}'''
        permissions.append(perm_block)
    
    # Add secrets manager permissions
    secret_vars = service_config.get('secret_variables', [])
    if secret_vars:
        perm_block = f'''    {{
      service   = "secretsmanager"
      actions   = ["secretsmanager:GetSecretValue"]
      resources = ["${{aws_secretsmanager_secret.service_secret.arn}}"]
    }}'''
        permissions.append(perm_block)
    
    # Add CloudWatch Logs permissions
    perm_block = f'''    {{
      service   = "logs"
      actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
      resources = ["*"]
    }}'''
    permissions.append(perm_block)
    
    return ',\n'.join(permissions)

def main():
    if len(sys.argv) < 3:
        print("Usage: python3 generate-service-infra.py <service.yaml> <environment> [version]")
        sys.exit(1)
    
    service_file = sys.argv[1]
    environment = sys.argv[2]
    version = sys.argv[3] if len(sys.argv) > 3 else None
    
    # Load service configuration
    with open(service_file, 'r') as f:
        service_config = yaml.safe_load(f)
    
    # Generate Terraform using modules
    tf_content = generate_ecs_service_tf(service_config, environment, version)
    
    # Create output directory in application folder
    service_name = service_config['name']
    output_dir = f"application/infrastructure"
    os.makedirs(output_dir, exist_ok=True)
    
    # Write Terraform file
    output_file = f"{output_dir}/main.tf"
    with open(output_file, 'w') as f:
        f.write(tf_content)
    
    print(f"Generated Terraform for {service_name} ({environment}) using modules: {output_file}")

if __name__ == '__main__':
    main()
