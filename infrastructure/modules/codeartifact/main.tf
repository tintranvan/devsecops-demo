# CodeArtifact Module for AWS-only Dependencies

# CodeArtifact Domain
resource "aws_codeartifact_domain" "main" {
  domain = "${var.name_prefix}-domain"
  
  tags = var.common_tags
}

# CodeArtifact Repository
resource "aws_codeartifact_repository" "main" {
  repository = "${var.name_prefix}-repo"
  domain     = aws_codeartifact_domain.main.domain

  upstream {
    repository_name = aws_codeartifact_repository.maven_central.repository
  }

  tags = var.common_tags
}

# Maven Central Upstream Repository
resource "aws_codeartifact_repository" "maven_central" {
  repository = "${var.name_prefix}-maven-central"
  domain     = aws_codeartifact_domain.main.domain

  external_connections {
    external_connection_name = "public:maven-central"
  }

  tags = var.common_tags
}

# Domain Policy
resource "aws_codeartifact_domain_permissions_policy" "main" {
  domain          = aws_codeartifact_domain.main.domain
  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = var.allowed_principals
        }
        Action = [
          "codeartifact:GetAuthorizationToken",
          "codeartifact:ReadFromRepository"
        ]
        Resource = "*"
      }
    ]
  })
}

# Repository Policy
resource "aws_codeartifact_repository_permissions_policy" "main" {
  repository      = aws_codeartifact_repository.main.repository
  domain          = aws_codeartifact_domain.main.domain
  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = var.allowed_principals
        }
        Action = [
          "codeartifact:DescribePackageVersion",
          "codeartifact:DescribeRepository",
          "codeartifact:GetPackageVersionReadme",
          "codeartifact:GetRepositoryEndpoint",
          "codeartifact:ListPackages",
          "codeartifact:ListPackageVersions",
          "codeartifact:ReadFromRepository"
        ]
        Resource = "*"
      }
    ]
  })
}

# VPC Endpoint for CodeArtifact
resource "aws_vpc_endpoint" "codeartifact_api" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.codeartifact.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [var.vpc_endpoints_security_group_id]
  private_dns_enabled = true

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-codeartifact-api-endpoint"
  })
}

resource "aws_vpc_endpoint" "codeartifact_repositories" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.codeartifact.repositories"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [var.vpc_endpoints_security_group_id]
  private_dns_enabled = true

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-codeartifact-repositories-endpoint"
  })
}
