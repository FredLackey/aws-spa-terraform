# S3 Bucket Module
# Creates S3 bucket for static asset hosting with CloudFront integration

# S3 bucket for static assets
resource "aws_s3_bucket" "static_assets" {
  bucket = var.bucket_name
  
  tags = var.tags
}

# S3 bucket versioning (disabled for cost optimization)
resource "aws_s3_bucket_versioning" "static_assets" {
  bucket = aws_s3_bucket.static_assets.id
  versioning_configuration {
    status = "Disabled"
  }
}

# S3 bucket server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "static_assets" {
  bucket = aws_s3_bucket.static_assets.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "static_assets" {
  bucket = aws_s3_bucket.static_assets.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Origin Access Control for CloudFront
resource "aws_cloudfront_origin_access_control" "s3_oac" {
  name                              = "${var.project_prefix}-${var.environment}-s3-oac"
  description                       = "OAC for S3 bucket access from CloudFront"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Bucket policy to allow CloudFront access only
# Note: This will be set after CloudFront distribution is created
resource "aws_s3_bucket_policy" "static_assets" {
  count  = var.cloudfront_distribution_arn != "" ? 1 : 0
  bucket = aws_s3_bucket.static_assets.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontServicePrincipal"
        Effect    = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.static_assets.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = var.cloudfront_distribution_arn
          }
        }
      }
    ]
  })
  
  depends_on = [aws_s3_bucket_public_access_block.static_assets]
}

# Upload placeholder React application files
resource "null_resource" "build_and_upload_react_app" {
  # Build the placeholder React application
  provisioner "local-exec" {
    command = <<-EOT
      cd ${path.root}/../../packages/placeholder-react-app
      npm ci
      npm run build
    EOT
  }
  
  # Upload built files to S3
  provisioner "local-exec" {
    command = <<-EOT
      aws s3 sync ${path.root}/../../packages/placeholder-react-app/dist/ s3://${aws_s3_bucket.static_assets.bucket}/ \
        --delete \
        --cache-control "public, max-age=31536000" \
        --exclude "index.html" \
        --exclude "*.map"
      
      # Upload index.html separately with shorter cache control
      aws s3 cp ${path.root}/../../packages/placeholder-react-app/dist/index.html s3://${aws_s3_bucket.static_assets.bucket}/index.html \
        --cache-control "public, max-age=300"
    EOT
  }
  
  # Trigger rebuild when files change
  triggers = {
    always_run = timestamp()
  }
  
  depends_on = [
    aws_s3_bucket.static_assets,
    aws_s3_bucket_policy.static_assets
  ]
}