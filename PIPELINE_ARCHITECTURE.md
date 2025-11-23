# DevSecOps Pipeline Architecture

## Pipeline Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                         MAIN PIPELINE                                │
│                  (.github/workflows/devsecops-pipeline.yml)          │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
                    ┌─────────────────────────┐
                    │   1. Environment Setup   │
                    │   - Set variables        │
                    │   - Configure AWS        │
                    └─────────────────────────┘
                                  │
                    ┌─────────────┴─────────────┐
                    ▼                           ▼
        ┌───────────────────────┐   ┌───────────────────────┐
        │ 2a. SAST Security     │   │ 2b. Dockerfile        │
        │     (Reusable)        │   │     Security          │
        │ ✓ SAST                │   │     (Reusable)        │
        │ ✓ IaC Scan            │   │ ✓ Hadolint            │
        │ ✓ SCA                 │   │ ✓ Trivy               │
        │ ✓ SBOM                │   │ ✓ Inspector           │
        └───────────────────────┘   └───────────────────────┘
                    │                           │
                    └─────────────┬─────────────┘
                                  ▼
                    ┌─────────────────────────┐
                    │   3. Build & Package     │
                    │   - Build Docker image   │
                    │   - Push to ECR          │
                    └─────────────────────────┘
                                  │
                    ┌─────────────┴─────────────┐
                    ▼                           ▼
        ┌───────────────────────┐   ┌───────────────────────┐
        │ 4a. Image Security    │   │ 4b. Container         │
        │     (Reusable)        │   │     Signing           │
        │ ✓ ECR Scan            │   │     (Reusable)        │
        │ ✓ Trivy               │   │ ✓ AWS Signer          │
        │ ✓ Vulnerability DB    │   │ ✓ Notation            │
        └───────────────────────┘   └───────────────────────┘
                    │                           │
                    └─────────────┬─────────────┘
                                  ▼
                    ┌─────────────────────────┐
                    │   5. Deploy to ECS       │
                    │   - Generate Terraform   │
                    │   - Apply infrastructure │
                    │   - Health check         │
                    │   - Auto rollback        │
                    └─────────────────────────┘
                                  │
                                  ▼
                    ┌─────────────────────────┐
                    │   6. DAST Security       │
                    │      (Reusable)          │
                    │   ✓ ZAP Scan             │
                    │   ✓ API Testing          │
                    └─────────────────────────┘
                                  │
                                  ▼
                    ┌─────────────────────────┐
                    │   7. Security Summary    │
                    │   - Aggregate results    │
                    │   - Generate reports     │
                    │   - Upload artifacts     │
                    └─────────────────────────┘
```

## Reusable Workflows Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                      REUSABLE WORKFLOWS                           │
└──────────────────────────────────────────────────────────────────┘

┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────────┐
│ security-sast.yml   │  │security-dockerfile  │  │security-image-scan  │
│                     │  │        .yml         │  │       .yml          │
│ Inputs:             │  │                     │  │                     │
│ - environment       │  │ Inputs:             │  │ Inputs:             │
│ - aws_region        │  │ - environment       │  │ - environment       │
│                     │  │ - aws_region        │  │ - aws_region        │
│ Secrets:            │  │                     │  │ - image_tag         │
│ - aws_role          │  │ Secrets:            │  │ - service_name      │
│                     │  │ - aws_role          │  │                     │
│ Outputs:            │  │                     │  │ Secrets:            │
│ - sast-outcome      │  │ Outputs:            │  │ - aws_role          │
│                     │  │ - dockerfile-outcome│  │                     │
│ Uses:               │  │                     │  │ Outputs:            │
│ - config.sh         │  │ Uses:               │  │ - scan-outcome      │
│ - security-SAST-... │  │ - config.sh         │  │                     │
│                     │  │ - security-inspec...│  │ Uses:               │
└─────────────────────┘  └─────────────────────┘  │ - config.sh         │
                                                   │ - security-images...│
┌─────────────────────┐  ┌─────────────────────┐  └─────────────────────┘
│security-container-  │  │  security-dast.yml  │
│   signing.yml       │  │                     │
│                     │  │ Inputs:             │
│ Inputs:             │  │ - environment       │
│ - environment       │  │ - aws_region        │
│ - aws_region        │  │ - target_url        │
│ - image_tag         │  │                     │
│ - service_name      │  │ Secrets:            │
│                     │  │ - aws_role          │
│ Secrets:            │  │                     │
│ - aws_role          │  │ Outputs:            │
│                     │  │ - dast-outcome      │
│ Outputs:            │  │                     │
│ - signing-outcome   │  │ Uses:               │
│                     │  │ - config.sh         │
│ Uses:               │  │ - security-dast.sh  │
│ - config.sh         │  └─────────────────────┘
│ - security-contai...│
└─────────────────────┘
```

## Workflow Library Structure

```
workflow-library/
│
├── config.sh                    ← Central Configuration
│   ├── AWS settings
│   ├── ECR configuration
│   ├── CodeArtifact settings
│   ├── Security settings
│   └── Helper functions
│
├── Deployment Scripts
│   ├── deploy-infra.sh
│   └── deploy-service.sh
│
├── Generation Scripts
│   ├── generate-security-report.py
│   └── generate-service-infra.py
│
└── Security Scripts
    ├── security-SAST-IaC-SCA-SBOM-PolicyasCode-check.sh
    ├── security-inspector-dockerfile-container-validation.sh
    ├── security-imagescaning.sh
    ├── security-container-signer.sh
    └── security-dast.sh
```

## Configuration Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    Configuration Hierarchy                       │
└─────────────────────────────────────────────────────────────────┘

GitHub Secrets                 Environment Variables
     │                                │
     ├─ AWS_ROLE_DEV                  ├─ AWS_REGION
     ├─ AWS_ROLE_STG                  ├─ AWS_ACCOUNT_ID
     └─ AWS_ROLE_PROD                 └─ (from pipeline)
            │                                │
            └────────────┬───────────────────┘
                         ▼
              ┌──────────────────────┐
              │   Main Pipeline      │
              │   - Setup job        │
              │   - Set outputs      │
              └──────────────────────┘
                         │
                         ▼
              ┌──────────────────────┐
              │  Reusable Workflows  │
              │  - Receive inputs    │
              │  - Source config.sh  │
              └──────────────────────┘
                         │
                         ▼
              ┌──────────────────────┐
              │   config.sh          │
              │   - Load defaults    │
              │   - Export variables │
              │   - Helper functions │
              └──────────────────────┘
                         │
                         ▼
              ┌──────────────────────┐
              │  Security Scripts    │
              │  - Use variables     │
              │  - Execute scans     │
              └──────────────────────┘
```

## Security Findings Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    Security Findings Pipeline                    │
└─────────────────────────────────────────────────────────────────┘

Security Scans
    │
    ├─ SAST ──────────┐
    ├─ Dockerfile ────┤
    ├─ Image Scan ────┤
    ├─ Container Sign ┤
    └─ DAST ──────────┘
            │
            ▼
    ┌──────────────────┐
    │  JSON Reports    │
    │  - findings.json │
    │  - results.json  │
    └──────────────────┘
            │
            ▼
    ┌──────────────────┐
    │ Report Generator │
    │ - Aggregate      │
    │ - Sort by severity│
    │ - Generate HTML  │
    └──────────────────┘
            │
            ├─────────────────┐
            ▼                 ▼
    ┌──────────────┐  ┌──────────────┐
    │ HTML Report  │  │ GitHub       │
    │ (Artifact)   │  │ Step Summary │
    └──────────────┘  └──────────────┘
            │
            ▼
    ┌──────────────────┐
    │  AWS Security Hub│
    │  (via SQS+Lambda)│
    └──────────────────┘
```

## Environment-Specific Behavior

```
┌─────────────────────────────────────────────────────────────────┐
│                    Environment Strategy                          │
└─────────────────────────────────────────────────────────────────┘

DEV Environment                    STAGING/PROD Environment
    │                                      │
    ├─ Security Scan Fails                ├─ Security Scan Fails
    │  └─ Continue with WARNING           │  └─ STOP Pipeline
    │                                      │
    ├─ Deployment Fails                   ├─ Deployment Fails
    │  └─ Show error, no rollback         │  └─ Auto rollback
    │                                      │
    ├─ Health Check Fails                 ├─ Health Check Fails
    │  └─ Rollback after 2 min            │  └─ Rollback after 3 min
    │                                      │
    └─ Fast Deployment                    └─ Safe Deployment
       └─ minimum_healthy_percent: 0         └─ minimum_healthy_percent: 50
```

## Artifact Management

```
Pipeline Run
    │
    ├─ SAST Reports ──────────┐
    ├─ Dockerfile Reports ────┤
    ├─ Image Scan Reports ────┤
    ├─ Signing Reports ───────┤
    ├─ DAST Reports ──────────┤
    └─ Security Summary ──────┘
                │
                ▼
        ┌──────────────────┐
        │ GitHub Artifacts │
        │ Retention: 30-90d│
        └──────────────────┘
                │
                ├─ sast-reports
                ├─ dockerfile-reports
                ├─ image-scan-reports
                ├─ signing-reports
                ├─ dast-reports-{env}
                └─ security-reports-{env}-{run}
```

## Key Features

### 1. Modularity
- Each security scan is independent
- Can be reused across pipelines
- Easy to add/remove scans

### 2. Centralization
- Single config file for all settings
- Consistent variable naming
- Shared helper functions

### 3. Flexibility
- Environment-specific behavior
- Configurable thresholds
- Optional scans

### 4. Observability
- Detailed step summaries
- Comprehensive reports
- Artifact retention

### 5. Reliability
- Auto-rollback on failure
- Health checks
- Error handling
