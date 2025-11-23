# Environment Configuration Guide

## 🎯 Overview

Tất cả environment variables giờ được quản lý tập trung trong các file `.env` rõ ràng, dễ hiểu.

## 📁 File Structure

```
.github/
├── config/
│   ├── README.md          # Documentation
│   ├── dev.env           # ⭐ Development config
│   ├── staging.env       # ⭐ Staging config
│   ├── prod.env          # ⭐ Production config
│   └── environments.yml  # Alternative YAML format
└── scripts/
    ├── load-env-vars.sh  # Load .env files
    └── load-env-config.sh # Load YAML config
```

## 🔍 Nhìn Vào Là Biết Cần Setup Gì

### Dev Environment (.github/config/dev.env)

```bash
# ═══════════════════════════════════════════════════════════
# DEVELOPMENT ENVIRONMENT CONFIGURATION
# ═══════════════════════════════════════════════════════════

# ┌─────────────────────────────────────────────────────────┐
# │ ENVIRONMENT INFO                                         │
# └─────────────────────────────────────────────────────────┘
ENVIRONMENT=dev
ENV_NAME=Development

# ┌─────────────────────────────────────────────────────────┐
# │ AWS CONFIGURATION                                        │
# └─────────────────────────────────────────────────────────┘
AWS_REGION=us-east-1
AWS_ACCOUNT_ID=647272350116

# ┌─────────────────────────────────────────────────────────┐
# │ SERVICE CONFIGURATION                                    │
# └─────────────────────────────────────────────────────────┘
SERVICE_NAME=demo-app
PROJECT_NAME=devsecops

# ┌─────────────────────────────────────────────────────────┐
# │ PIPELINE BEHAVIOR                                        │
# └─────────────────────────────────────────────────────────┘
CONTINUE_ON_ERROR=true          # ✅ Allow warnings in dev
FAIL_ON_SECURITY_ISSUES=false   # ⚠️  Don't block on security

# ┌─────────────────────────────────────────────────────────┐
# │ URLS                                                     │
# └─────────────────────────────────────────────────────────┘
TARGET_URL=https://dev-service-01.editforreal.com
API_URL=https://api-dev.editforreal.com

# ┌─────────────────────────────────────────────────────────┐
# │ ECS CONFIGURATION                                        │
# └─────────────────────────────────────────────────────────┘
ECS_CLUSTER=devsecops-dev-cluster
ECR_REPO=devsecops-dev-java-app
MIN_HEALTHY_PERCENT=0           # 🚀 Fast deployment
HEALTH_CHECK_GRACE_PERIOD=10    # ⚡ Quick feedback
DESIRED_COUNT=1                 # 💰 Minimal cost

# ┌─────────────────────────────────────────────────────────┐
# │ CODEARTIFACT                                            │
# └─────────────────────────────────────────────────────────┘
CODEARTIFACT_DOMAIN=devsecops-domain
CODEARTIFACT_REPO=python-packages

# ┌─────────────────────────────────────────────────────────┐
# │ SECURITY                                                │
# └─────────────────────────────────────────────────────────┘
SIGNER_PROFILE=devsecops_image_demo_sign
SECURITY_FINDINGS_QUEUE=security-findings-queue

# ┌─────────────────────────────────────────────────────────┐
# │ TIMEOUTS (seconds)                                      │
# └─────────────────────────────────────────────────────────┘
HEALTH_CHECK_TIMEOUT=120        # 2 minutes
DEPLOYMENT_TIMEOUT=600          # 10 minutes
```

## 📊 Environment Comparison Table

| Variable | Dev | Staging | Prod | Purpose |
|----------|-----|---------|------|---------|
| **ENVIRONMENT** | dev | staging | prod | Environment identifier |
| **ENV_NAME** | Development | Staging | Production | Display name |
| **AWS_REGION** | us-east-1 | us-east-1 | us-east-1 | AWS region |
| **AWS_ACCOUNT_ID** | 647272350116 | 647272350116 | 647272350116 | AWS account |
| **SERVICE_NAME** | demo-app | demo-app | demo-app | Service name |
| **CONTINUE_ON_ERROR** | ✅ true | ❌ false | ❌ false | Allow failures |
| **FAIL_ON_SECURITY_ISSUES** | ❌ false | ✅ true | ✅ true | Block on security |
| **TARGET_URL** | dev-service-01... | staging-service-01... | prod-service-01... | DAST target |
| **ECS_CLUSTER** | devsecops-dev-cluster | devsecops-staging-cluster | devsecops-prod-cluster | ECS cluster |
| **ECR_REPO** | devsecops-dev-java-app | devsecops-staging-java-app | devsecops-prod-java-app | ECR repo |
| **MIN_HEALTHY_PERCENT** | 0% | 50% | 100% | Deployment strategy |
| **HEALTH_CHECK_GRACE_PERIOD** | 10s | 30s | 60s | Health check wait |
| **DESIRED_COUNT** | 1 | 2 | 3 | Number of tasks |
| **HEALTH_CHECK_TIMEOUT** | 120s | 180s | 300s | Health check max |
| **DEPLOYMENT_TIMEOUT** | 600s | 900s | 1200s | Deployment max |

## 🔄 How It Works

### Before (Scattered Config)

```
❌ Hardcoded in workflow file
❌ Hardcoded in scripts
❌ Hardcoded in multiple places
❌ Hard to see what needs to be configured
❌ Hard to update
```

### After (Centralized Config)

```
✅ All config in .env files
✅ One file per environment
✅ Clear sections and comments
✅ Easy to see all variables
✅ Easy to update
```

## 🚀 Usage Examples

### 1. View Current Configuration

```bash
# Load dev config
source .github/config/dev.env

# Display summary
echo "Environment: $ENV_NAME"
echo "Service: $SERVICE_NAME"
echo "Cluster: $ECS_CLUSTER"
echo "Continue on Error: $CONTINUE_ON_ERROR"
```

### 2. Update Configuration

```bash
# Edit dev config
vim .github/config/dev.env

# Change value
MIN_HEALTHY_PERCENT=50

# Commit
git add .github/config/dev.env
git commit -m "Update dev min healthy percent"
git push
```

### 3. Add New Variable

```bash
# Add to all environment files
echo "NEW_VARIABLE=dev_value" >> .github/config/dev.env
echo "NEW_VARIABLE=staging_value" >> .github/config/staging.env
echo "NEW_VARIABLE=prod_value" >> .github/config/prod.env

# Use in workflow
source .github/config/${ENVIRONMENT}.env
echo "New var: $NEW_VARIABLE"
```

### 4. Compare Environments

```bash
# Show differences
diff .github/config/dev.env .github/config/prod.env

# Or use a better diff tool
code --diff .github/config/dev.env .github/config/prod.env
```

### 5. Validate Configuration

```bash
# Check all required variables are set
for env in dev staging prod; do
  echo "Validating $env..."
  source .github/config/${env}.env
  
  # Check required variables
  [ -z "$SERVICE_NAME" ] && echo "❌ SERVICE_NAME missing" || echo "✅ SERVICE_NAME: $SERVICE_NAME"
  [ -z "$ECS_CLUSTER" ] && echo "❌ ECS_CLUSTER missing" || echo "✅ ECS_CLUSTER: $ECS_CLUSTER"
  [ -z "$TARGET_URL" ] && echo "❌ TARGET_URL missing" || echo "✅ TARGET_URL: $TARGET_URL"
done
```

## 📝 Quick Reference

### What Goes in .env Files?

✅ **Include:**
- Environment names
- AWS regions and account IDs
- Service names
- URLs
- ECS/ECR configuration
- Timeouts and thresholds
- Feature flags

❌ **Don't Include:**
- AWS credentials (use GitHub Secrets)
- API keys (use GitHub Secrets)
- Passwords (use GitHub Secrets)
- Private keys (use GitHub Secrets)

### File Locations

```
Configuration Files:
  .github/config/dev.env      ← Dev environment
  .github/config/staging.env  ← Staging environment
  .github/config/prod.env     ← Production environment

Helper Scripts:
  .github/scripts/load-env-vars.sh  ← Load .env files

Documentation:
  .github/config/README.md          ← Detailed docs
  ENVIRONMENT_CONFIG_GUIDE.md       ← This guide
```

## 🎓 Best Practices

### 1. Keep Files in Sync
All environment files should have the same variables (different values):

```bash
# Good ✅
dev.env:     SERVICE_NAME=demo-app
staging.env: SERVICE_NAME=demo-app
prod.env:    SERVICE_NAME=demo-app

# Bad ❌
dev.env:     SERVICE_NAME=demo-app
staging.env: SERVICE_NAME=demo-app
prod.env:    # Missing SERVICE_NAME
```

### 2. Use Comments
Add comments to explain non-obvious values:

```bash
# Good ✅
MIN_HEALTHY_PERCENT=0  # Fast deployment for dev testing

# Bad ❌
MIN_HEALTHY_PERCENT=0
```

### 3. Group Related Variables
Use sections to organize variables:

```bash
# ┌─────────────────────────────────────────────────────────┐
# │ AWS CONFIGURATION                                        │
# └─────────────────────────────────────────────────────────┘
AWS_REGION=us-east-1
AWS_ACCOUNT_ID=647272350116
```

### 4. Provide Defaults
Use default values where appropriate:

```bash
# In script
AWS_REGION=${AWS_REGION:-us-east-1}
DESIRED_COUNT=${DESIRED_COUNT:-1}
```

### 5. Document Changes
Add comments when changing values:

```bash
# Updated 2025-11-23: Increased for better availability
DESIRED_COUNT=3
```

## 🔧 Troubleshooting

### Variable Not Set

```bash
# Check if variable exists
source .github/config/dev.env
echo "SERVICE_NAME: ${SERVICE_NAME:-NOT SET}"

# If not set, add to .env file
echo "SERVICE_NAME=demo-app" >> .github/config/dev.env
```

### Wrong Environment Loaded

```bash
# Check which environment is loaded
echo "Current environment: $ENVIRONMENT"

# Load correct environment
source .github/config/prod.env
echo "Now using: $ENVIRONMENT"
```

### Config File Not Found

```bash
# Check file exists
ls -la .github/config/

# Create if missing
cp .github/config/dev.env .github/config/new-env.env
```

## 📚 Related Documentation

- [.github/config/README.md](.github/config/README.md) - Detailed config docs
- [QUICK_REFERENCE.md](QUICK_REFERENCE.md) - Quick start guide
- [PIPELINE_ARCHITECTURE.md](PIPELINE_ARCHITECTURE.md) - Architecture overview

---

**Summary:** Tất cả environment variables giờ được quản lý tập trung trong các file `.env` rõ ràng. Nhìn vào file là biết ngay cần setup những gì!
