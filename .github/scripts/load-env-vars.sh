#!/bin/bash
# Load environment variables from .env file
# Usage: source load-env-vars.sh <environment>

set -e

ENVIRONMENT=${1:-dev}
ENV_FILE=".github/config/${ENVIRONMENT}.env"

if [ ! -f "$ENV_FILE" ]; then
    echo "❌ Environment file not found: $ENV_FILE"
    echo "Available environments: dev, staging, prod"
    exit 1
fi

echo "📋 Loading environment configuration from: $ENV_FILE"
echo ""

# Load and export all variables from .env file
set -a  # Automatically export all variables
source "$ENV_FILE"
set +a

# Derived variables
export ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
export ECR_REPO_FULL="${ECR_REGISTRY}/${ECR_REPO}"

echo "✅ Configuration loaded successfully"
echo ""
echo "📊 Environment Summary:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Environment:              $ENV_NAME ($ENVIRONMENT)"
echo "AWS Region:               $AWS_REGION"
echo "AWS Account:              $AWS_ACCOUNT_ID"
echo "Service Name:             $SERVICE_NAME"
echo "Continue on Error:        $CONTINUE_ON_ERROR"
echo "Target URL:               $TARGET_URL"
echo "ECS Cluster:              $ECS_CLUSTER"
echo "ECR Repository:           $ECR_REPO"
echo "Min Healthy Percent:      $MIN_HEALTHY_PERCENT%"
echo "Health Check Grace:       ${HEALTH_CHECK_GRACE_PERIOD}s"
echo "Desired Count:            $DESIRED_COUNT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
