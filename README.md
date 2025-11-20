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
- **AWS CodeGuru Reviewer** - SAST for code quality and security
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
├── infrastructure/
│   ├── core/                 # Pre-provisioned infrastructure
│   ├── application/          # ECS service, task definitions
│   └── security/            # Security Hub, Lambda functions
├── application/
│   ├── src/                 # Java Spring Boot application
│   ├── Dockerfile           # Multi-stage build
│   └── docker-compose.yml   # Local development
├── pipeline/
│   ├── buildspec.yml        # CodeBuild specification
│   ├── security-scan.yml    # Security scanning configuration
│   └── deploy.yml           # Deployment configuration
├── security/
│   ├── lambda/              # Security findings processor
│   ├── policies/            # IAM policies
│   └── reports/             # Security report templates
└── docs/
    ├── deployment.md        # Deployment guide
    └── security.md          # Security implementation details
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

## Getting Started

1. **Prerequisites Setup**
   ```bash
   # Clone repository
   git clone <repository-url>
   cd devsecops-assessment
   
   # Configure AWS credentials
   aws configure
   ```

2. **Infrastructure Deployment**
   ```bash
   cd infrastructure
   terraform init
   terraform plan -var-file="environments/dev.tfvars"
   terraform apply
   ```

3. **Application Deployment**
   ```bash
   # Trigger pipeline
   git push origin main
   ```

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
