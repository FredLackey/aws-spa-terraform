#!/bin/bash

# Stage 02 Infrastructure Setup - Deployment Script
# Deploys complete SPA infrastructure with CloudFront, Lambda, S3, and Route53

set -euo pipefail

# Script directory and imports
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/scripts/utils.sh"

# Initialize logging
log_execution "deploy"

echo "=== Stage 02 Infrastructure Setup - Deployment ==="
echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo

# Parse command line parameters for Lambda configuration
parse_lambda_params "$@"

# Load configuration from Stage 01 output
load_configuration

# Validate that environment and region are not provided as parameters
validate_no_env_region_params "$@"

echo "=== Configuration Summary ==="
echo "Project: $PROJECT_PREFIX-$ENVIRONMENT"
echo "Region: $REGION"
echo "Domain: $DOMAIN"
echo "Certificate ARN: $CERTIFICATE_ARN"
echo "VPC ID: $VPC_ID"
echo "Lambda Memory: ${LAMBDA_MEMORY}MB"
echo "Lambda Timeout: ${LAMBDA_TIMEOUT}s"
echo

# Initialize Terraform backend
echo "=== Initializing Terraform Backend ==="
terraform init \
  -backend-config="bucket=$BACKEND_BUCKET" \
  -backend-config="key=${PROJECT_PREFIX}/${ENVIRONMENT}/02-infra-setup/terraform.tfstate" \
  -backend-config="region=$REGION" \
  -backend-config="dynamodb_table=$BACKEND_TABLE" \
  -backend-config="encrypt=true"

echo

# Create terraform.tfvars file with configuration
echo "=== Creating Terraform Variables File ==="
cat > terraform.tfvars <<EOF
# Auto-generated variables from Stage 01 configuration
project_prefix                = "$PROJECT_PREFIX"
environment                   = "$ENVIRONMENT"
region                        = "$REGION"
domain                        = "$DOMAIN"
certificate_arn               = "$CERTIFICATE_ARN"
vpc_id                        = "$VPC_ID"
cross_account_role_arn        = "$CROSS_ACCOUNT_ROLE_ARN"
backend_bucket                = "$BACKEND_BUCKET"
backend_table                 = "$BACKEND_TABLE"
infrastructure_profile        = "$(get_config_value '.aws.infrastructure_profile')"
hosting_profile               = "$(get_config_value '.aws.hosting_profile')"

# Lambda configuration from command line parameters
lambda_memory                 = $LAMBDA_MEMORY
lambda_timeout                = $LAMBDA_TIMEOUT

# Additional configuration
s3_bucket_name                = "${PROJECT_PREFIX}-${ENVIRONMENT}-static-assets"
cloudfront_price_class        = "PriceClass_100"

additional_tags = {
  DeployedBy = "deploy-script"
  DeployedAt = "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

echo "Terraform variables file created: terraform.tfvars"
echo

# Plan deployment
echo "=== Planning Terraform Deployment ==="
terraform plan \
  -var-file="terraform.tfvars" \
  -out="tfplan"

echo

# Apply deployment
echo "=== Applying Terraform Deployment ==="
terraform apply "tfplan"

echo

# Wait for CloudFront distribution to be deployed (can take 15-20 minutes)
echo "=== Waiting for CloudFront Distribution Deployment ==="
echo "This may take 15-20 minutes for CloudFront to fully deploy..."

DISTRIBUTION_ID=$(terraform output -raw cloudfront_distribution_id)
if [[ -n "$DISTRIBUTION_ID" ]]; then
    echo "CloudFront Distribution ID: $DISTRIBUTION_ID"
    echo "Waiting for deployment to complete..."
    
    # Wait for distribution to be deployed
    aws cloudfront wait distribution-deployed --id "$DISTRIBUTION_ID" --region us-east-1
    
    echo "CloudFront distribution deployment completed!"
else
    echo "Warning: Could not retrieve CloudFront distribution ID"
fi

echo

# Generate output configuration for Stage 03
echo "=== Generating Output Configuration ==="
generate_output_config

echo

# Display deployment summary
echo "=== Deployment Summary ==="
echo "✅ Infrastructure deployed successfully!"
echo
echo "Application URL: $(terraform output -raw application_url)"
echo "API Base URL: $(terraform output -raw api_base_url)"
echo "CloudFront Distribution ID: $(terraform output -raw cloudfront_distribution_id)"
echo "Lambda Function Name: $(terraform output -raw lambda_function_name)"
echo "S3 Bucket Name: $(terraform output -raw s3_bucket_name)"
echo

echo "=== Next Steps ==="
echo "1. Run validation script: ./scripts/validation.sh"
echo "2. Test the application in your browser at: $(terraform output -raw application_url)"
echo "3. Test API endpoints using the React application's test button"
echo "4. Check CloudWatch logs for Lambda function execution"
echo

echo "Deployment completed at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"