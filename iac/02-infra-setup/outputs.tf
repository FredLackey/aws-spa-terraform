# Stage 02 Infrastructure Setup - Output Definitions
# Values for Stage 03 consumption and validation

# S3 outputs
output "s3_bucket_name" {
  description = "Name of the S3 bucket for static assets"
  value       = module.s3.bucket_name
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket for static assets"
  value       = module.s3.bucket_arn
}

output "s3_bucket_regional_domain_name" {
  description = "Regional domain name of the S3 bucket"
  value       = module.s3.bucket_regional_domain_name
}

# Lambda outputs
output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = module.lambda.function_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = module.lambda.function_arn
}

output "lambda_function_url" {
  description = "Function URL for direct CloudFront integration"
  value       = module.lambda.function_url
  sensitive   = false
}

output "lambda_function_url_id" {
  description = "Function URL configuration ID"
  value       = module.lambda.function_url_id
}

# CloudFront outputs
output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution"
  value       = module.cloudfront.distribution_id
}

output "cloudfront_distribution_arn" {
  description = "ARN of the CloudFront distribution"
  value       = module.cloudfront.distribution_arn
}

output "cloudfront_domain_name" {
  description = "Domain name of the CloudFront distribution"
  value       = module.cloudfront.domain_name
}

output "cloudfront_hosted_zone_id" {
  description = "Hosted zone ID of the CloudFront distribution"
  value       = module.cloudfront.hosted_zone_id
}

# Route 53 outputs
output "route53_record_name" {
  description = "Name of the Route 53 record"
  value       = module.route53.record_name
}

output "route53_record_fqdn" {
  description = "FQDN of the Route 53 record"
  value       = module.route53.record_fqdn
}

# Application outputs
output "application_url" {
  description = "Primary application URL (custom domain)"
  value       = "https://${var.domain}"
}

output "api_base_url" {
  description = "Base URL for API endpoints"
  value       = "https://${var.domain}/api"
}

# Configuration summary
output "configuration_summary" {
  description = "Summary of deployed infrastructure configuration"
  value = {
    project_prefix  = var.project_prefix
    environment     = var.environment
    region          = var.region
    domain          = var.domain
    lambda_memory   = var.lambda_memory
    lambda_timeout  = var.lambda_timeout
    s3_bucket       = module.s3.bucket_name
    cloudfront_id   = module.cloudfront.distribution_id
  }
}