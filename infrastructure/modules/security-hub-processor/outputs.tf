output "lambda_function_arn" {
  description = "ARN of the Security Hub processor Lambda function"
  value       = aws_lambda_function.security_hub_processor.arn
}

output "lambda_function_name" {
  description = "Name of the Security Hub processor Lambda function"
  value       = aws_lambda_function.security_hub_processor.function_name
}

output "sqs_queue_url" {
  description = "URL of the SQS queue for security findings"
  value       = aws_sqs_queue.security_findings_queue.url
}

output "sqs_queue_arn" {
  description = "ARN of the SQS queue for security findings"
  value       = aws_sqs_queue.security_findings_queue.arn
}

output "dlq_queue_url" {
  description = "URL of the dead letter queue"
  value       = aws_sqs_queue.security_findings_dlq.url
}
