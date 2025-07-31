# CloudFront Module Variables

variable "project_prefix" {
  description = "Project prefix for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod, etc.)"
  type        = string
}

variable "domain" {
  description = "Custom domain name for the CloudFront distribution"
  type        = string
}

variable "certificate_arn" {
  description = "SSL certificate ARN from ACM"
  type        = string
}

variable "price_class" {
  description = "CloudFront price class"
  type        = string
  default     = "PriceClass_100"
}

# S3 origin configuration
variable "s3_bucket_name" {
  description = "Name of the S3 bucket for static assets"
  type        = string
}

variable "s3_bucket_regional_domain_name" {
  description = "Regional domain name of the S3 bucket"
  type        = string
}

variable "s3_origin_access_control_id" {
  description = "Origin Access Control ID for S3 bucket (if pre-existing)"
  type        = string
  default     = ""
}

# Lambda origin configuration
variable "lambda_function_url" {
  description = "Lambda Function URL for API requests"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}