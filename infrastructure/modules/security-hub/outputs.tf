output "security_hub_account_id" {
  description = "Security Hub account ID"
  value       = var.enable_security_hub ? aws_securityhub_account.main[0].id : null
}

output "guardduty_detector_id" {
  description = "GuardDuty detector ID"
  value       = var.enable_guardduty ? aws_guardduty_detector.main[0].id : null
}

output "security_findings_lambda_arn" {
  description = "ARN of the Security Findings Lambda function"
  value       = aws_lambda_function.security_findings_processor.arn
}
