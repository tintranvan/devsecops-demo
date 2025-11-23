#!/bin/bash

# Deploy Service Script
# Usage: ./deploy-service.sh <service-name> <environment> [profile] [version]

set -e

SERVICE_NAME=${1:-demo-app}
ENVIRONMENT=${2:-dev}
AWS_PROFILE=${3:-esoftvn-researching}
VERSION=${4:-$(date +%Y%m%d-%H%M%S)}
ECR_REPO="647272350116.dkr.ecr.us-east-1.amazonaws.com/devsecops-${ENVIRONMENT}-java-app"

echo "🚀 Deploying ${SERVICE_NAME} to ${ENVIRONMENT} environment with version ${VERSION}..."

# 1. Build and push Docker image
echo "📦 Building Docker image..."
cd application

# Get CodeArtifact auth token
echo "🔐 Getting CodeArtifact auth token..."
CODEARTIFACT_AUTH_TOKEN=$(AWS_PROFILE=${AWS_PROFILE} aws codeartifact get-authorization-token \
  --domain devsecops-domain \
  --domain-owner 647272350116 \
  --region us-east-1 \
  --query authorizationToken \
  --output text)

# Create temporary pip.conf
echo "📝 Creating temporary pip.conf..."
cat > pip.conf << EOF
[global]
index-url = https://aws:${CODEARTIFACT_AUTH_TOKEN}@devsecops-domain-647272350116.d.codeartifact.us-east-1.amazonaws.com/pypi/python-packages/simple/
EOF

# Build with pip.conf, then cleanup
docker build --platform linux/amd64 -f Dockerfile -t ${ECR_REPO}:${VERSION} .
rm -f pip.conf

echo "🔐 Logging into ECR..."
AWS_PROFILE=${AWS_PROFILE} aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 647272350116.dkr.ecr.us-east-1.amazonaws.com

echo "📤 Pushing image to ECR..."
docker push ${ECR_REPO}:${VERSION}

# 2. Generate Terraform with version
echo "🏗️  Generating Terraform configuration..."
cd ..
python3 scripts/generate-service-infra.py application/service.yaml ${ENVIRONMENT} ${VERSION}

# 3. Deploy infrastructure
echo "🌍 Deploying infrastructure..."
cd application/infrastructure
AWS_PROFILE=${AWS_PROFILE} terraform init -reconfigure
AWS_PROFILE=${AWS_PROFILE} terraform apply -auto-approve

echo "✅ Deployment completed successfully!"
echo "🔗 Service URL: https://dev-service-01.editforreal.com/"
echo "📦 Image: ${ECR_REPO}:${VERSION}"
