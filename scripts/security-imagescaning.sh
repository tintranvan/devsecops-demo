#!/bin/bash

# ECR Build, Push and Inspector Scan Script
set -e

# Configuration
AWS_PROFILE="esoftvn-researching"
AWS_REGION="us-east-1"
ACCOUNT_ID="647272350116"
ENVIRONMENT="${ENVIRONMENT:-dev}"
ECR_REPOSITORY="devsecops-${ENVIRONMENT}-java-app"
IMAGE_TAG="${IMAGE_TAG:-$(date +%Y%m%d-%H%M%S)}"
DOCKERFILE_PATH="application/Dockerfile"
BUILD_CONTEXT="application"
OUTPUT_DIR="security/ecr"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🚀 ECR Build, Push & Inspector Scan${NC}"
echo "=================================================="

mkdir -p "$OUTPUT_DIR"

# Get AWS Account ID (already known from deploy-service.sh)
ECR_URI="$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY"

echo -e "${BLUE}📋 Configuration:${NC}"
echo "  Account: $ACCOUNT_ID"
echo "  Region: $AWS_REGION"
echo "  Repository: $ECR_REPOSITORY"
echo "  Image Tag: $IMAGE_TAG"
echo "  ECR URI: $ECR_URI:$IMAGE_TAG"

# Step 1: Create ECR repository if not exists
echo -e "${BLUE}📦 Creating ECR repository...${NC}"
aws ecr create-repository \
    --repository-name "$ECR_REPOSITORY" \
    --region "$AWS_REGION" \
    --profile "$AWS_PROFILE" 2>/dev/null || {
    echo "  ℹ️  Repository already exists"
}

# Step 2: Login to ECR
echo -e "${BLUE}🔐 Logging into ECR...${NC}"
aws ecr get-login-password \
    --region "$AWS_REGION" \
    --profile "$AWS_PROFILE" | docker login \
    --username AWS \
    --password-stdin "$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"

# Step 3: Build Docker image with CodeArtifact integration
echo -e "${BLUE}🏗️  Building Docker image with CodeArtifact...${NC}"
cd "$BUILD_CONTEXT"

# Get CodeArtifact auth token
echo -e "${BLUE}🔐 Getting CodeArtifact auth token...${NC}"
CODEARTIFACT_AUTH_TOKEN=$(aws codeartifact get-authorization-token \
  --domain devsecops-domain \
  --domain-owner "$ACCOUNT_ID" \
  --region "$AWS_REGION" \
  --profile "$AWS_PROFILE" \
  --query authorizationToken \
  --output text)

# Create temporary pip.conf
echo -e "${BLUE}📝 Creating temporary pip.conf...${NC}"
cat > pip.conf << EOF
[global]
index-url = https://aws:${CODEARTIFACT_AUTH_TOKEN}@devsecops-domain-${ACCOUNT_ID}.d.codeartifact.${AWS_REGION}.amazonaws.com/pypi/python-packages/simple/
EOF

# Build Docker image
docker build --platform linux/amd64 -f Dockerfile -t "$ECR_REPOSITORY:$IMAGE_TAG" .
docker tag "$ECR_REPOSITORY:$IMAGE_TAG" "$ECR_URI:$IMAGE_TAG"

# Cleanup pip.conf
rm -f pip.conf
cd ..

# Step 4: Push to ECR
echo -e "${BLUE}📤 Pushing image to ECR...${NC}"
docker push "$ECR_URI:$IMAGE_TAG"

echo -e "${GREEN}✅ Image pushed successfully: $ECR_URI:$IMAGE_TAG${NC}"

# Step 5: Enable Inspector scanning
echo -e "${BLUE}🔧 Enabling Inspector ECR scanning...${NC}"
aws inspector2 enable --resource-types ECR --region "$AWS_REGION" --profile "$AWS_PROFILE" 2>/dev/null || {
    echo "  ℹ️  Inspector ECR already enabled"
}

# Step 6: Trigger scan
echo -e "${BLUE}🔍 Triggering Inspector scan...${NC}"
aws ecr start-image-scan \
    --repository-name "$ECR_REPOSITORY" \
    --image-id imageTag="$IMAGE_TAG" \
    --region "$AWS_REGION" \
    --profile "$AWS_PROFILE" || {
    echo "  ⚠️  Scan may already be in progress"
}

# Step 7: Wait for scan completion and get results
echo -e "${BLUE}⏳ Waiting for scan completion...${NC}"
max_attempts=30
attempt=0

while [ $attempt -lt $max_attempts ]; do
    scan_status=$(aws ecr describe-image-scan-findings \
        --repository-name "$ECR_REPOSITORY" \
        --image-id imageTag="$IMAGE_TAG" \
        --region "$AWS_REGION" \
        --profile "$AWS_PROFILE" \
        --query 'imageScanStatus.status' \
        --output text 2>/dev/null || echo "IN_PROGRESS")
    
    if [ "$scan_status" = "COMPLETE" ]; then
        echo -e "${GREEN}✅ Scan completed successfully${NC}"
        break
    elif [ "$scan_status" = "FAILED" ]; then
        echo -e "${RED}❌ Scan failed${NC}"
        exit 1
    else
        echo "  ⏳ Scan in progress... ($((attempt + 1))/$max_attempts)"
        sleep 10
        ((attempt++))
    fi
done

if [ $attempt -eq $max_attempts ]; then
    echo -e "${YELLOW}⚠️  Scan timeout, retrieving partial results...${NC}"
fi

# Step 8: Get scan results
echo -e "${BLUE}📊 Retrieving scan results...${NC}"
aws ecr describe-image-scan-findings \
    --repository-name "$ECR_REPOSITORY" \
    --image-id imageTag="$IMAGE_TAG" \
    --region "$AWS_REGION" \
    --profile "$AWS_PROFILE" > "$OUTPUT_DIR/ecr_scan_results_${TIMESTAMP}.json"

# Step 9: Analyze results
analyze_scan_results() {
    local results_file="$1"
    
    echo -e "${BLUE}📋 ECR Inspector Scan Analysis${NC}"
    echo "=============================="
    
    if command -v jq &> /dev/null; then
        # Extract summary
        total_findings=$(jq '.imageScanFindings.findings | length' "$results_file" 2>/dev/null || echo 0)
        critical_count=$(jq '[.imageScanFindings.findings[] | select(.severity == "CRITICAL")] | length' "$results_file" 2>/dev/null || echo 0)
        high_count=$(jq '[.imageScanFindings.findings[] | select(.severity == "HIGH")] | length' "$results_file" 2>/dev/null || echo 0)
        medium_count=$(jq '[.imageScanFindings.findings[] | select(.severity == "MEDIUM")] | length' "$results_file" 2>/dev/null || echo 0)
        low_count=$(jq '[.imageScanFindings.findings[] | select(.severity == "LOW")] | length' "$results_file" 2>/dev/null || echo 0)
        
        echo "📊 Vulnerability Summary:"
        echo "  Critical: $critical_count"
        echo "  High: $high_count"
        echo "  Medium: $medium_count"
        echo "  Low: $low_count"
        echo "  Total: $total_findings"
        
        if [ "$total_findings" -gt 0 ]; then
            echo ""
            echo "🔍 Top 5 Critical/High Vulnerabilities:"
            jq -r '.imageScanFindings.findings[] | select(.severity == "CRITICAL" or .severity == "HIGH") | "- \(.severity): \(.name) - \(.description)"' "$results_file" 2>/dev/null | head -5
        fi
        
        # Generate summary report
        cat > "$OUTPUT_DIR/ecr_scan_report_${TIMESTAMP}.md" << EOF
# ECR Inspector Scan Report

**Generated:** $(date)
**Image:** $ECR_URI:$IMAGE_TAG
**Repository:** $ECR_REPOSITORY
**Scan Status:** $(jq -r '.imageScanStatus.status' "$results_file")

## Summary

| Severity | Count |
|----------|-------|
| Critical | $critical_count |
| High     | $high_count |
| Medium   | $medium_count |
| Low      | $low_count |
| **Total** | **$total_findings** |

## Security Assessment

$(if [ "$total_findings" -eq 0 ]; then
    echo "✅ **PASS**: No vulnerabilities detected"
elif [ "$critical_count" -gt 0 ]; then
    echo "🚨 **CRITICAL**: $critical_count critical vulnerabilities require immediate attention"
elif [ "$high_count" -gt 0 ]; then
    echo "⚠️  **HIGH**: $high_count high severity vulnerabilities should be addressed"
else
    echo "ℹ️  **REVIEW**: $total_findings medium/low severity findings for review"
fi)

## Top Vulnerabilities

$(jq -r '.imageScanFindings.findings[] | select(.severity == "CRITICAL" or .severity == "HIGH") | "### \(.severity): \(.name)\n\n**Description:** \(.description)\n\n**URI:** \(.uri)\n\n---\n"' "$results_file" 2>/dev/null | head -20)

## Files Generated

- \`ecr_scan_results_${TIMESTAMP}.json\` - Complete scan results
- \`ecr_scan_report_${TIMESTAMP}.md\` - This report

## Next Steps

1. **Critical/High**: Fix immediately before production deployment
2. **Medium**: Plan remediation in next development cycle  
3. **Low**: Monitor and address as needed
4. **Update base images** and rebuild if vulnerabilities found
5. **Integrate into CI/CD** pipeline for automated scanning

EOF
        
        echo ""
        echo -e "${GREEN}✅ Analysis completed${NC}"
        echo -e "${BLUE}📁 Reports saved to: $OUTPUT_DIR${NC}"
        echo -e "${BLUE}📋 Report: ecr_scan_report_${TIMESTAMP}.md${NC}"
        
        # Return appropriate exit code
        if [ "$critical_count" -gt 0 ]; then
            echo -e "${RED}🚨 CRITICAL vulnerabilities found - blocking deployment${NC}"
            return 1
        elif [ "$high_count" -gt 0 ]; then
            echo -e "${YELLOW}⚠️  HIGH severity vulnerabilities found - review required${NC}"
            return 1
        else
            echo -e "${GREEN}✅ No critical/high vulnerabilities - safe for deployment${NC}"
            return 0
        fi
    else
        echo "⚠️  jq not available for detailed analysis"
        echo "📄 Raw scan results saved to: $results_file"
        return 0
    fi
}

# Analyze results
analyze_scan_results "$OUTPUT_DIR/ecr_scan_results_${TIMESTAMP}.json"
scan_exit_code=$?

# Cleanup local images
echo -e "${BLUE}🧹 Cleaning up local images...${NC}"
docker rmi "$ECR_REPOSITORY:$IMAGE_TAG" "$ECR_URI:$IMAGE_TAG" 2>/dev/null || true

echo ""
echo -e "${GREEN}🎉 ECR build, push and scan completed!${NC}"
echo -e "${BLUE}🔗 View in ECR Console: https://$AWS_REGION.console.aws.amazon.com/ecr/repositories/private/$ACCOUNT_ID/$ECR_REPOSITORY${NC}"

exit $scan_exit_code
