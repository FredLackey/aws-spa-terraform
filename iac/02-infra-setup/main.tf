# Stage 02 Infrastructure Setup - Root Terraform Configuration
# Defines providers and modules for complete SPA infrastructure

# Data sources for configuration discovery
data "aws_caller_identity" "infrastructure" {
  provider = aws.infrastructure
}

data "aws_caller_identity" "hosting" {
  provider = aws.hosting
}

data "aws_region" "current" {
  provider = aws.hosting
}

# Local variables and configuration
locals {
  s3_bucket_name = var.s3_bucket_name != "" ? var.s3_bucket_name : "${var.project_prefix}-${var.environment}-static-assets"
  
  # Extract hosted zone from domain (e.g., "thuapp.sbx.briskhaven.com" -> "briskhaven.com")
  domain_parts = split(".", var.domain)
  hosted_zone_name = join(".", slice(local.domain_parts, length(local.domain_parts) - 2, length(local.domain_parts)))
  
  common_tags = merge(
    {
      Project     = var.project_prefix
      Environment = var.environment
      Stage       = "02-infra-setup"
      ManagedBy   = "terraform"
    },
    var.additional_tags
  )
}

# S3 bucket for static asset hosting
module "s3" {
  source = "./modules/s3"
  
  providers = {
    aws = aws.hosting
  }
  
  bucket_name     = local.s3_bucket_name
  project_prefix  = var.project_prefix
  environment     = var.environment
  
  tags = local.common_tags
}

# Lambda function with Function URLs
module "lambda" {
  source = "./modules/lambda"
  
  providers = {
    aws = aws.hosting
  }
  
  project_prefix  = var.project_prefix
  environment     = var.environment
  vpc_id          = var.vpc_id
  memory_size     = var.lambda_memory
  timeout         = var.lambda_timeout
  
  tags = local.common_tags
}

# CloudFront distribution
module "cloudfront" {
  source = "./modules/cloudfront"
  
  providers = {
    aws = aws.hosting
  }
  
  project_prefix         = var.project_prefix
  environment           = var.environment
  domain                = var.domain
  certificate_arn       = var.certificate_arn
  price_class           = var.cloudfront_price_class
  
  # S3 origin configuration
  s3_bucket_name                = module.s3.bucket_name
  s3_bucket_regional_domain_name = module.s3.bucket_regional_domain_name
  s3_origin_access_control_id   = module.s3.origin_access_control_id
  
  # Lambda origin configuration
  lambda_function_url = module.lambda.function_url
  
  tags = local.common_tags
}

# Route 53 DNS records
module "route53" {
  source = "./modules/route53"
  
  providers = {
    aws = aws.hosting
  }
  
  domain                        = var.domain
  hosted_zone_name              = local.hosted_zone_name
  cloudfront_distribution_id    = module.cloudfront.distribution_id
  cloudfront_domain_name        = module.cloudfront.domain_name
  cloudfront_hosted_zone_id     = module.cloudfront.hosted_zone_id
  
  tags = local.common_tags
}