# Security Hub Module

# Enable Security Hub
resource "aws_securityhub_account" "main" {
  count                    = var.enable_security_hub ? 1 : 0
  enable_default_standards = true
}

# # Enable Inspector V2
# resource "aws_inspector2_enabler" "main" {
#   count          = var.enable_inspector ? 1 : 0
#   account_ids    = [data.aws_caller_identity.current.account_id]
#   resource_types = ["ECR", "EC2"]
# }

# Enable GuardDuty
resource "aws_guardduty_detector" "main" {
  count  = var.enable_guardduty ? 1 : 0
  enable = true

  datasources {
    s3_logs {
      enable = true
    }
    kubernetes {
      audit_logs {
        enable = true
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          enable = true
        }
      }
    }
  }

  tags = var.common_tags
}

# Lambda function for processing security findings
resource "aws_lambda_function" "security_findings_processor" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "${var.name_prefix}-security-findings-processor"
  role            = aws_iam_role.lambda_role.arn
  handler         = "index.handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime         = "python3.9"
  timeout         = 60

  environment {
    variables = {
      SECURITY_HUB_REGION = data.aws_region.current.name
    }
  }

  tags = var.common_tags
}

# Lambda function code
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "/tmp/security_findings_processor.zip"
  source {
    content = <<EOF
import json
import boto3
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def handler(event, context):
    logger.info(f"Received event: {json.dumps(event)}")
    
    # Process security findings
    repository = event.get('repository', 'unknown')
    commit_sha = event.get('commit_sha', 'unknown')
    findings_count = event.get('findings_count', 0)
    
    logger.info(f"Processing {findings_count} findings for {repository}@{commit_sha}")
    
    # Here you can add custom logic for processing findings
    # For example: send notifications, create tickets, etc.
    
    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': f'Processed {findings_count} security findings',
            'repository': repository,
            'commit': commit_sha
        })
    }
EOF
    filename = "index.py"
  }
}

# IAM role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "${var.name_prefix}-security-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.common_tags
}

# Lambda execution policy
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Security Hub access policy
resource "aws_iam_role_policy" "lambda_security_hub" {
  name = "${var.name_prefix}-lambda-security-hub-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "securityhub:BatchImportFindings",
          "securityhub:GetFindings",
          "securityhub:UpdateFindings"
        ]
        Resource = "*"
      }
    ]
  })
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
