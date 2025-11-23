# DevSecOps Assessment - Java Application CI/CD Pipeline

## Overview
This project implements a comprehensive DevSecOps pipeline for a Java application using AWS native services, following security-first principles with centralized findings management through AWS Security Hub.

## Architecture

### Core Infrastructure (Pre-provisioned)
- VPC with public/private subnets
- Application Load Balancer (ALB) with SSL certificate
- ECS Cluster (Fargate)
- IAM roles and policies
- Security Hub for centralized security findings

### Application Stack
- **Java Spring Boot Application** (mock service)
- **Amazon SQS** for message queuing
- **Amazon RDS** for database
- **Amazon ECR** for container registry
- **ECS Fargate** for container orchestration

## DevSecOps Pipeline Stages

### 1. Code Analysis (SAST & CSA)
- **AWS Security Inspector Reviewer** - SAST for code quality and security
- **Amazon CodeWhisperer** - Code security analysis
- **AWS Secrets Manager Scanner** - Secret detection
- **Lambda Function** - Send findings to Security Hub (ASFF format)

### 2. Build & Image Security
- **AWS CodeBuild** with approved base images only
- **External dependency monitoring** - Alert to Security Hub
- **SBOM Generation** using AWS Inspector
- **ECR Image Scanning** before push
- **Image signing** with AWS Signer

### 3. Continuous Testing
- **Unit Tests** with JUnit
- **Integration Tests** with Testcontainers
- **Security Tests** with OWASP Dependency Check
- **Performance Tests** with JMeter

### 4. Deployment & Runtime Security
- **Terraform** for infrastructure deployment
- **AWS Inspector** for runtime vulnerability assessment
- **AWS GuardDuty** for runtime threat detection
- **AWS WAF** for application protection
- **DAST** with AWS Inspector or third-party tools

## Environment Promotion Strategy

```
Development → Staging → Production
     ↓           ↓          ↓
  Allow with    Fix all    Clean image
  warnings      issues     promotion only
```

### Security Gates
- **Dev**: Warnings allowed, continue deployment
- **Staging**: All HIGH/CRITICAL issues must be fixed
- **Production**: Only clean images from staging promoted

## Project Structure

```
devsecops-assessment/
├── .github/workflows/
│   ├── devsecops-pipeline.yml          # Main CI/CD pipeline
│   ├── security-sast.yml               # SAST/IaC/SCA/SBOM (reusable)
│   ├── security-dockerfile.yml         # Dockerfile scan (reusable)
│   ├── security-image-scan.yml         # Image scan (reusable)
│   ├── security-container-signing.yml  # Container signing (reusable)
│   └── security-dast.yml               # DAST scan (reusable)
├── workflow-library/
│   ├── config.sh                       # ⭐ Central configuration
│   ├── deploy-infra.sh                 # Infrastructure deployment
│   ├── deploy-service.sh               # Service deployment
│   ├── generate-security-report.py     # Security report generator
│   ├── generate-service-infra.py       # Terraform config generator
│   └── security-*.sh                   # Security scan scripts
├── infrastructure/
│   ├── core/                           # Pre-provisioned infrastructure
│   ├── modules/                        # Terraform modules
│   │   └── ecs-service/               # ECS service module
│   └── environments/                   # Environment configs
├── application/
│   ├── app.py                          # Python Flask application
│   ├── Dockerfile                      # Multi-stage build
│   ├── service.yaml                    # Service configuration
│   └── infrastructure/                 # Generated Terraform
├── security/
│   ├── ecr/                           # Image scan reports
│   ├── inspector/                     # SAST/Dockerfile reports
│   └── reports/                       # Aggregated security reports
└── docs/
    ├── PIPELINE_REFACTORING.md        # Refactoring details
    ├── PIPELINE_ARCHITECTURE.md       # Architecture diagrams
    ├── REFACTORING_CHECKLIST.md       # Completion checklist
    └── QUICK_REFERENCE.md             # Quick reference guide
```

## Key Features

### Security-First Approach
- All security findings centralized in AWS Security Hub
- ASFF (AWS Security Finding Format) compliance
- Zero-trust network architecture
- Least privilege IAM policies

### AWS Native Integration
- No external dependencies in build process
- AWS-approved base images only
- Native AWS security services integration
- Cost-optimized with AWS native tools

### Automated Security Validation
- Pre-commit hooks for local security checks
- Automated vulnerability scanning at every stage
- Runtime security monitoring
- Compliance reporting automation

## Pipeline Architecture (v2.0 - Refactored)

### Modular Design
The pipeline has been refactored into **reusable workflows** for better maintainability:

- **Main Pipeline**: Orchestrates all stages
- **Reusable Workflows**: Independent security scans
- **Centralized Config**: Single source of truth (`workflow-library/config.sh`)
- **Workflow Library**: Shared scripts and utilities

### Pipeline Flow
```
Setup → SAST/Dockerfile (parallel) → Build → Image Scan/Signing (parallel) 
  → Deploy → DAST → Security Summary
```

### Key Improvements
- ✅ **80% code reusability** with modular workflows
- ✅ **Centralized configuration** in `config.sh`
- ✅ **25% reduction** in main pipeline size
- ✅ **Independent testing** of security scans
- ✅ **Easy to extend** with new security checks

## Getting Started

1. **Prerequisites Setup**
   ```bash
   # Clone repository
   git clone <repository-url>
   cd devsecops-assessment
   
   # Configure AWS credentials (or use OIDC)
   aws configure
   ```

2. **Configure GitHub Secrets**
   ```bash
   # Set AWS IAM roles for OIDC
   gh secret set AWS_ROLE_DEV --body "arn:aws:iam::ACCOUNT:role/github-actions-dev"
   gh secret set AWS_ROLE_STG --body "arn:aws:iam::ACCOUNT:role/github-actions-staging"
   gh secret set AWS_ROLE_PROD --body "arn:aws:iam::ACCOUNT:role/github-actions-prod"
   ```

3. **Update Configuration**
   ```bash
   # Edit workflow-library/config.sh
   export AWS_ACCOUNT_ID="YOUR_ACCOUNT_ID"
   export AWS_REGION="us-east-1"
   ```

4. **Infrastructure Deployment**
   ```bash
   cd infrastructure
   terraform init
   terraform plan -var-file="environments/dev.tfvars"
   terraform apply
   ```

5. **Trigger Pipeline**
   ```bash
   # Push to trigger pipeline
   git push origin refactor
   
   # Or trigger manually
   gh workflow run devsecops-pipeline.yml -f environment=dev
   ```

## Quick Reference

### Run Individual Security Scans
```bash
# SAST scan
gh workflow run security-sast.yml -f environment=dev

# Dockerfile scan
gh workflow run security-dockerfile.yml -f environment=dev

# Image scan
gh workflow run security-image-scan.yml \
  -f environment=dev -f image_tag=dev-123 -f service_name=demo-app

# DAST scan
gh workflow run security-dast.yml \
  -f environment=dev -f target_url=https://dev-service.example.com
```

### View Pipeline Status
```bash
# List recent runs
gh run list --workflow=devsecops-pipeline.yml

# Watch specific run
gh run watch <run-id>

# Download security reports
gh run download <run-id> -n security-reports-dev-123
```

### Update Configuration
```bash
# Edit central config
vim workflow-library/config.sh

# Changes apply to all workflows automatically
git add workflow-library/config.sh
git commit -m "Update configuration"
git push
```

## Documentation

- 📖 [QUICK_REFERENCE.md](./QUICK_REFERENCE.md) - Quick start guide
- 🏗️ [PIPELINE_ARCHITECTURE.md](./PIPELINE_ARCHITECTURE.md) - Architecture diagrams
- 📝 [PIPELINE_REFACTORING.md](./PIPELINE_REFACTORING.md) - Refactoring details
- ✅ [REFACTORING_CHECKLIST.md](./REFACTORING_CHECKLIST.md) - Completion status

## Security Report Template

The pipeline generates comprehensive security reports including:
- SAST findings summary
- Dependency vulnerability report
- Container image security assessment
- DAST results
- Compliance status
- Remediation recommendations

## Monitoring & Alerting

- **CloudWatch** for application metrics
- **Security Hub** for security findings
- **SNS** for security alerts
- **Lambda** for automated response

## Compliance & Governance

- SOC 2 Type II compliance ready
- GDPR data protection measures
- Audit trail for all deployments
- Automated compliance reporting

---

*This assessment demonstrates enterprise-grade DevSecOps practices using AWS native services with security-first principles.*
# devsecops-demo
# Security scan trigger
