# CloudFront Distribution Module
# Creates CloudFront distribution with behaviors for React app and API

# Origin Access Control for S3
resource "aws_cloudfront_origin_access_control" "s3_oac" {
  name                              = "${var.project_prefix}-${var.environment}-s3-oac"
  description                       = "OAC for S3 bucket access"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "main" {
  # S3 origin for React application
  origin {
    domain_name              = var.s3_bucket_regional_domain_name
    origin_id                = "s3-${var.s3_bucket_name}"
    origin_access_control_id = aws_cloudfront_origin_access_control.s3_oac.id
  }
  
  # Lambda Function URL origin for API
  origin {
    domain_name = replace(replace(var.lambda_function_url, "https://", ""), "/", "")
    origin_id   = "lambda-${var.project_prefix}-${var.environment}-api"
    
    custom_origin_config {
      http_port              = 443
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }
  
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  price_class         = var.price_class
  
  # Aliases (custom domain)
  aliases = [var.domain]
  
  # Default behavior - serve React application from S3
  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-${var.s3_bucket_name}"
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
    
    # Standard caching for static assets
    cache_policy_id = data.aws_cloudfront_cache_policy.managed_caching_optimized.id
    
    # CORS headers for React application
    response_headers_policy_id = aws_cloudfront_response_headers_policy.cors_policy.id
  }
  
  # API behavior - forward to Lambda Function URL
  ordered_cache_behavior {
    path_pattern           = "/api/*"
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "lambda-${var.project_prefix}-${var.environment}-api"
    compress               = false
    viewer_protocol_policy = "redirect-to-https"
    
    # No caching for API requests
    cache_policy_id = data.aws_cloudfront_cache_policy.managed_caching_disabled.id
    
    # Forward all headers, query strings, and cookies
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.managed_cors_s3_origin.id
    
    # CORS headers for API responses
    response_headers_policy_id = aws_cloudfront_response_headers_policy.cors_policy.id
  }
  
  # SSL certificate configuration
  viewer_certificate {
    acm_certificate_arn      = var.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
  
  # Error pages for SPA routing
  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }
  
  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }
  
  # Geographic restrictions (none by default)
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  
  tags = var.tags
}

# CORS Response Headers Policy
resource "aws_cloudfront_response_headers_policy" "cors_policy" {
  name = "${var.project_prefix}-${var.environment}-cors-policy"
  
  cors_config {
    access_control_allow_credentials = false
    
    access_control_allow_headers {
      items = ["*"]
    }
    
    access_control_allow_methods {
      items = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    }
    
    access_control_allow_origins {
      items = ["*"]
    }
    
    origin_override = false
  }
}

# Data sources for managed policies
data "aws_cloudfront_cache_policy" "managed_caching_optimized" {
  name = "Managed-CachingOptimized"
}

data "aws_cloudfront_cache_policy" "managed_caching_disabled" {
  name = "Managed-CachingDisabled"
}

data "aws_cloudfront_origin_request_policy" "managed_cors_s3_origin" {
  name = "Managed-CORS-S3Origin"
}