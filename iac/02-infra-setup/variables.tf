# Stage 02 Infrastructure Setup - Variable Definitions
# Configurable parameters for memory, timeout, and discovered configuration

# Automatically discovered from Stage 01 configuration
variable "project_prefix" {
  description = "Project prefix for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod, etc.)"
  type        = string
}

variable "region" {
  description = "AWS region for resources"
  type        = string
}

variable "domain" {
  description = "Custom domain name for the application"
  type        = string
}

variable "certificate_arn" {
  description = "SSL certificate ARN from ACM"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for Lambda functions"
  type        = string
}

variable "cross_account_role_arn" {
  description = "Cross-account IAM role ARN for hosting account access"
  type        = string
}

variable "backend_bucket" {
  description = "S3 bucket name for Terraform state"
  type        = string
}

variable "backend_table" {
  description = "DynamoDB table name for Terraform state locking"
  type        = string
}

variable "infrastructure_profile" {
  description = "AWS profile for infrastructure account"
  type        = string
}

variable "hosting_profile" {
  description = "AWS profile for hosting account"
  type        = string
}

# Optional configurable parameters
variable "lambda_memory" {
  description = "Memory allocation for Lambda functions in MB"
  type        = number
  default     = 128
  
  validation {
    condition     = var.lambda_memory >= 128 && var.lambda_memory <= 10240
    error_message = "Lambda memory must be between 128 and 10240 MB."
  }
}

variable "lambda_timeout" {
  description = "Timeout for Lambda functions in seconds"
  type        = number
  default     = 15
  
  validation {
    condition     = var.lambda_timeout >= 1 && var.lambda_timeout <= 900
    error_message = "Lambda timeout must be between 1 and 900 seconds."
  }
}

# CloudFront configuration
variable "cloudfront_price_class" {
  description = "CloudFront price class"
  type        = string
  default     = "PriceClass_100"
  
  validation {
    condition = contains([
      "PriceClass_All",
      "PriceClass_200", 
      "PriceClass_100"
    ], var.cloudfront_price_class)
    error_message = "CloudFront price class must be PriceClass_All, PriceClass_200, or PriceClass_100."
  }
}

# S3 configuration
variable "s3_bucket_name" {
  description = "S3 bucket name for static assets (auto-generated if not provided)"
  type        = string
  default     = ""
}

# Tagging
variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}