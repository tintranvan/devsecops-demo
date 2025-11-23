# DevSecOps Pipeline - Quick Reference Guide

## 🚀 Quick Start

### Trigger Pipeline
```bash
# Push to branch
git push origin refactor

# Manual trigger
gh workflow run devsecops-pipeline.yml -f environment=dev
```

### Check Pipeline Status
```bash
# List recent runs
gh run list --workflow=devsecops-pipeline.yml

# Watch specific run
gh run watch <run-id>

# View logs
gh run view <run-id> --log
```

## 📁 File Structure

```
.github/workflows/
├── devsecops-pipeline.yml          # Main pipeline
├── security-sast.yml               # SAST/IaC/SCA/SBOM (reusable)
├── security-dockerfile.yml         # Dockerfile scan (reusable)
├── security-image-scan.yml         # Image scan (reusable)
├── security-container-signing.yml  # Container signing (reusable)
└── security-dast.yml               # DAST scan (reusable)

workflow-library/
├── config.sh                       # ⭐ Central configuration
├── deploy-infra.sh
├── deploy-service.sh
├── generate-security-report.py
├── generate-service-infra.py
└── security-*.sh                   # Security scan scripts
```

## ⚙️ Configuration

### Update Configuration
Edit `workflow-library/config.sh`:

```bash
# AWS Configuration
export AWS_ACCOUNT_ID="647272350116"
export AWS_REGION="us-east-1"

# ECR Configuration
export ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

# Security Configuration
export SIGNER_PROFILE_NAME="devsecops_image_demo_sign"

# Project Configuration
export PROJECT_NAME="devsecops"
export SERVICE_NAME="demo-app"
```

### GitHub Secrets Required
```
AWS_ROLE_DEV      # AWS IAM role for dev environment
AWS_ROLE_STG      # AWS IAM role for staging environment
AWS_ROLE_PROD     # AWS IAM role for prod environment
```

## 🔍 Security Scans

### SAST/IaC/SCA/SBOM
```bash
# Run manually
cd workflow-library
./security-SAST-IaC-SCA-SBOM-PolicyasCode-check.sh none us-east-1

# Or trigger workflow
gh workflow run security-sast.yml -f environment=dev
```

**Scans:**
- AWS Inspector (SAST)
- Terraform validation (IaC)
- Dependency scanning (SCA)
- SBOM generation

### Dockerfile Security
```bash
# Run manually
cd workflow-library
./security-inspector-dockerfile-container-validation.sh none us-east-1

# Or trigger workflow
gh workflow run security-dockerfile.yml -f environment=dev
```

**Tools:**
- Hadolint
- Trivy
- AWS Inspector

### Image Security
```bash
# Run manually
export ENVIRONMENT=dev
export IMAGE_TAG=dev-123
cd workflow-library
./security-imagescaning.sh

# Or trigger workflow
gh workflow run security-image-scan.yml \
  -f environment=dev \
  -f image_tag=dev-123 \
  -f service_name=demo-app
```

**Scans:**
- ECR image scanning
- Trivy vulnerability scan
- CVE database check

### Container Signing
```bash
# Run manually
cd workflow-library
./security-container-signer.sh \
  "647272350116.dkr.ecr.us-east-1.amazonaws.com/devsecops-dev-java-app:dev-123" \
  "devsecops_image_demo_sign" \
  "us-east-1"

# Or trigger workflow
gh workflow run security-container-signing.yml \
  -f environment=dev \
  -f image_tag=dev-123 \
  -f service_name=demo-app
```

**Tools:**
- AWS Signer
- Notation

### DAST
```bash
# Run manually
cd workflow-library
./security-dast.sh https://dev-service-01.editforreal.com

# Or trigger workflow
gh workflow run security-dast.yml \
  -f environment=dev \
  -f target_url=https://dev-service-01.editforreal.com
```

**Tools:**
- OWASP ZAP
- API security testing

## 🏗️ Build & Deploy

### Build Docker Image
```bash
# Happens automatically in pipeline
# Manual build:
cd application
docker build -t demo-app:latest .
```

### Deploy to Environment
```bash
# Via pipeline (automatic)
git push origin main  # → prod
git push origin staging  # → staging
git push origin develop  # → dev

# Manual deployment
cd workflow-library
./deploy-service.sh demo-app dev us-east-1
```

### Generate Infrastructure
```bash
# Generate Terraform config
cd workflow-library
python3 generate-service-infra.py \
  ../application/service.yaml \
  dev \
  dev-123
```

## 📊 Reports & Artifacts

### Download Reports
```bash
# List artifacts
gh run view <run-id> --json artifacts

# Download specific artifact
gh run download <run-id> -n security-reports-dev-123

# Download all artifacts
gh run download <run-id>
```

### Report Locations
```
security/
├── ecr/                    # Image scan reports
│   ├── *.json
│   └── *.md
├── inspector/              # SAST/Dockerfile reports
│   ├── sast_findings_*.json
│   └── dockerfile_findings_*.json
└── reports/                # Aggregated reports
    ├── security-summary-*.json
    ├── security-summary-*.html
    ├── zap-*.json          # DAST reports
    └── notation-*.json     # Signing reports
```

### View Security Summary
```bash
# In GitHub Actions UI
# Go to: Actions → Run → Summary tab

# Or download HTML report
gh run download <run-id> -n security-reports-dev-123
open security/reports/security-summary-*.html
```

## 🔧 Troubleshooting

### Pipeline Fails at Security Scan

**Dev Environment:**
- Pipeline continues with warnings
- Check artifacts for detailed reports
- Fix issues before promoting to staging

**Staging/Prod Environment:**
- Pipeline stops immediately
- Must fix all security issues
- Re-run pipeline after fixes

### Deployment Fails

**Check logs:**
```bash
gh run view <run-id> --log | grep -A 20 "Deploy"
```

**Common issues:**
- AWS credentials expired
- ECS service not healthy
- Terraform state locked

**Rollback:**
- Automatic in pipeline (health check failure)
- Manual: Previous task definition restored

### Health Check Timeout

**Dev:** 2 minutes max
**Staging/Prod:** 3 minutes max

**If timeout:**
1. Check ECS service status
2. Check task logs
3. Verify security groups
4. Check target group health

### Script Not Found

**Error:** `script not found, skipping...`

**Fix:**
```bash
# Ensure scripts are executable
chmod +x workflow-library/*.sh

# Commit and push
git add workflow-library/
git commit -m "Fix script permissions"
git push
```

## 🎯 Common Tasks

### Add New Security Scan

1. Create script in `workflow-library/`:
```bash
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

# Your scan logic here
```

2. Create reusable workflow in `.github/workflows/`:
```yaml
name: New Security Scan (Reusable)
on:
  workflow_call:
    inputs:
      environment:
        required: true
        type: string
    secrets:
      aws_role:
        required: true
    outputs:
      scan-outcome:
        value: ${{ jobs.scan.outputs.outcome }}
```

3. Add to main pipeline:
```yaml
new-security-scan:
  uses: ./.github/workflows/new-security-scan.yml
  with:
    environment: ${{ needs.setup.outputs.environment }}
  secrets:
    aws_role: ${{ secrets.AWS_ROLE }}
```

### Update AWS Account ID

1. Edit `workflow-library/config.sh`:
```bash
export AWS_ACCOUNT_ID="NEW_ACCOUNT_ID"
```

2. Update main pipeline env (optional):
```yaml
env:
  AWS_ACCOUNT_ID: "NEW_ACCOUNT_ID"
```

3. Commit and push

### Change Security Thresholds

Edit security scripts in `workflow-library/`:
```bash
# Example: security-imagescaning.sh
CRITICAL_THRESHOLD=0  # Fail if any critical
HIGH_THRESHOLD=5      # Fail if > 5 high
```

### Add New Environment

1. Create GitHub secret:
```bash
gh secret set AWS_ROLE_NEW_ENV --body "arn:aws:iam::..."
```

2. Update pipeline setup job:
```yaml
- name: Set deployment variables
  run: |
    if [ "${{ github.ref }}" = "refs/heads/new-env" ]; then
      ENVIRONMENT="new-env"
    fi
```

3. Update role selection:
```yaml
role-to-assume: ${{ needs.setup.outputs.environment == 'new-env' && secrets.AWS_ROLE_NEW_ENV || ... }}
```

## 📞 Support

### Documentation
- [PIPELINE_REFACTORING.md](./PIPELINE_REFACTORING.md) - Refactoring details
- [PIPELINE_ARCHITECTURE.md](./PIPELINE_ARCHITECTURE.md) - Architecture diagrams
- [REFACTORING_CHECKLIST.md](./REFACTORING_CHECKLIST.md) - Completion checklist

### Useful Commands
```bash
# Check workflow syntax
gh workflow view devsecops-pipeline.yml

# List all workflows
gh workflow list

# Enable/disable workflow
gh workflow enable devsecops-pipeline.yml
gh workflow disable devsecops-pipeline.yml

# View workflow file
gh workflow view devsecops-pipeline.yml --yaml

# Cancel running workflow
gh run cancel <run-id>
```

### Debug Mode
Add to workflow:
```yaml
- name: Debug
  run: |
    echo "Environment: ${{ needs.setup.outputs.environment }}"
    echo "Service: ${{ needs.setup.outputs.service_name }}"
    env | sort
```

## 🔐 Security Best Practices

1. **Never commit secrets** - Use GitHub Secrets
2. **Rotate AWS roles** regularly
3. **Review security reports** before promoting
4. **Keep dependencies updated**
5. **Monitor Security Hub** for findings
6. **Test in dev first** before staging/prod
7. **Use signed images** in production
8. **Enable branch protection** for main/staging

## 📈 Performance Tips

1. **Use caching** for dependencies
2. **Run scans in parallel** where possible
3. **Optimize Docker builds** with multi-stage
4. **Use smaller base images**
5. **Clean up old artifacts** regularly
6. **Monitor pipeline duration**
7. **Profile slow steps**

---

**Last Updated:** 2025-11-23
**Version:** 2.0 (Refactored)
