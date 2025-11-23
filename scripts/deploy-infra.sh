#!/bin/bash

set -e

ENVIRONMENT=${1:-dev}
AWS_REGION=${2:-us-east-1}
AWS_PROFILE=${3:-esoftvn-researching}

echo "🚀 Deploying DevSecOps Infrastructure"
echo "   Environment: $ENVIRONMENT"
echo "   AWS Region: $AWS_REGION"
echo "   AWS Profile: $AWS_PROFILE"

# Set AWS profile
export AWS_PROFILE=$AWS_PROFILE

# Check if AWS CLI is configured
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo "❌ AWS CLI not configured for profile: $AWS_PROFILE"
    exit 1
fi

echo "✅ AWS Profile configured: $(aws sts get-caller-identity --query Account --output text)"

# Navigate to infrastructure directory
cd "$(dirname "$0")/../infrastructure/core"

# Initialize Terraform with environment-specific backend
echo "📦 Initializing Terraform..."
terraform init -backend-config="key=${ENVIRONMENT}/core/terraform.tfstate"

# Validate Terraform configuration
echo "✅ Validating Terraform configuration..."
terraform validate

# Plan deployment
echo "📋 Planning deployment..."
terraform plan -var-file="../environments/${ENVIRONMENT}.tfvars" -out=tfplan

# Ask for confirmation
echo ""
echo "🤔 Do you want to apply this plan? (y/N)"
read -r response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo "🔨 Applying Terraform plan..."
    terraform apply tfplan
    
    echo ""
    echo "✅ Infrastructure deployment completed!"
    echo "📊 Getting outputs..."
    terraform output
else
    echo "❌ Deployment cancelled"
    rm -f tfplan
    exit 1
fi

# Clean up plan file
rm -f tfplan

echo ""
echo "🎉 DevSecOps infrastructure deployed successfully!"
echo "🔗 Next steps:"
echo "   1. Update DNS records to point to ALB: $(terraform output -raw alb_dns_name 2>/dev/null || echo 'N/A')"
echo "   2. Validate SSL certificate if created"
echo "   3. Deploy application using CI/CD pipeline"
