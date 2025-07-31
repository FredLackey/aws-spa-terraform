# S3 Module Variables

variable "bucket_name" {
  description = "Name of the S3 bucket for static assets"
  type        = string
}

variable "project_prefix" {
  description = "Project prefix for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod, etc.)"
  type        = string
}

variable "cloudfront_distribution_arn" {
  description = "CloudFront distribution ARN for bucket policy (optional during initial creation)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}