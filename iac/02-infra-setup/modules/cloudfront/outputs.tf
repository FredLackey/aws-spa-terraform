# CloudFront Module Outputs

output "distribution_id" {
  description = "ID of the CloudFront distribution"
  value       = aws_cloudfront_distribution.main.id
}

output "distribution_arn" {
  description = "ARN of the CloudFront distribution"
  value       = aws_cloudfront_distribution.main.arn
}

output "domain_name" {
  description = "Domain name of the CloudFront distribution"
  value       = aws_cloudfront_distribution.main.domain_name
}

output "hosted_zone_id" {
  description = "Hosted zone ID of the CloudFront distribution"
  value       = aws_cloudfront_distribution.main.hosted_zone_id
}

output "origin_access_control_id" {
  description = "Origin Access Control ID for S3 bucket"
  value       = aws_cloudfront_origin_access_control.s3_oac.id
}

output "response_headers_policy_id" {
  description = "Response headers policy ID for CORS"
  value       = aws_cloudfront_response_headers_policy.cors_policy.id
}