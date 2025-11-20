output "domain_name" {
  description = "CodeArtifact domain name"
  value       = aws_codeartifact_domain.main.domain
}

output "repository_name" {
  description = "CodeArtifact repository name"
  value       = aws_codeartifact_repository.main.repository
}

output "repository_endpoint" {
  description = "CodeArtifact repository endpoint"
  value       = "https://${aws_codeartifact_domain.main.domain}-${data.aws_caller_identity.current.account_id}.d.codeartifact.${var.aws_region}.amazonaws.com/maven/${aws_codeartifact_repository.main.repository}/"
}

output "domain_arn" {
  description = "CodeArtifact domain ARN"
  value       = aws_codeartifact_domain.main.arn
}

output "repository_arn" {
  description = "CodeArtifact repository ARN"
  value       = aws_codeartifact_repository.main.arn
}

data "aws_caller_identity" "current" {}
