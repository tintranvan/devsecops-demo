module "security_hub_processor" {
  source = "./modules/security-hub-processor"
}

output "security_hub_processor_outputs" {
  value = {
    lambda_function_arn  = module.security_hub_processor.lambda_function_arn
    lambda_function_name = module.security_hub_processor.lambda_function_name
    sqs_queue_url       = module.security_hub_processor.sqs_queue_url
    sqs_queue_arn       = module.security_hub_processor.sqs_queue_arn
    dlq_queue_url       = module.security_hub_processor.dlq_queue_url
  }
}
