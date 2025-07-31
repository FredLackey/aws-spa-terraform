# S3 Module Outputs

output "bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.static_assets.bucket
}

output "bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.static_assets.arn
}

output "bucket_id" {
  description = "ID of the S3 bucket"
  value       = aws_s3_bucket.static_assets.id
}

output "bucket_regional_domain_name" {
  description = "Regional domain name of the S3 bucket"
  value       = aws_s3_bucket.static_assets.bucket_regional_domain_name
}

output "bucket_domain_name" {
  description = "Domain name of the S3 bucket"
  value       = aws_s3_bucket.static_assets.bucket_domain_name
}

output "origin_access_control_id" {
  description = "Origin Access Control ID for CloudFront"
  value       = aws_cloudfront_origin_access_control.s3_oac.id
}