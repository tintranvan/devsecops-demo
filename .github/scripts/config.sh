#!/bin/bash
# Workflow Library Configuration
# Central configuration for all workflow scripts

# AWS Configuration
export AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-647272350116}"
export AWS_REGION="${AWS_REGION:-us-east-1}"
export AWS_PROFILE="${AWS_PROFILE:-}"

# ECR Configuration
export ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

# CodeArtifact Configuration
export CODEARTIFACT_DOMAIN="${CODEARTIFACT_DOMAIN:-devsecops-domain}"
export CODEARTIFACT_REPO="${CODEARTIFACT_REPO:-python-packages}"

# Terraform Configuration
export TERRAFORM_STATE_BUCKET="${TERRAFORM_STATE_BUCKET:-terraform-state-${AWS_ACCOUNT_ID}}"

# Security Configuration
export SECURITY_FINDINGS_QUEUE="${SECURITY_FINDINGS_QUEUE:-security-findings-queue}"
export SIGNER_PROFILE_NAME="${SIGNER_PROFILE_NAME:-devsecops_image_demo_sign}"

# Project Configuration
export PROJECT_NAME="${PROJECT_NAME:-devsecops}"
export SERVICE_NAME="${SERVICE_NAME:-demo-app}"

# Helper function to get AWS account ID dynamically
get_aws_account_id() {
    local profile=$1
    if [ "$profile" = "none" ] || [ -z "$profile" ]; then
        aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "${AWS_ACCOUNT_ID}"
    else
        aws sts get-caller-identity --profile "$profile" --query Account --output text 2>/dev/null || echo "${AWS_ACCOUNT_ID}"
    fi
}

# Helper function for AWS CLI calls with optional profile
aws_cli() {
    if [ -z "$AWS_PROFILE" ] || [ "$AWS_PROFILE" = "none" ]; then
        aws "$@"
    else
        aws "$@" --profile "$AWS_PROFILE"
    fi
}

echo "✅ Workflow configuration loaded"
echo "   AWS Account: ${AWS_ACCOUNT_ID}"
echo "   AWS Region: ${AWS_REGION}"
echo "   ECR Registry: ${ECR_REGISTRY}"
