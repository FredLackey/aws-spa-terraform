#!/bin/bash

# Stage 02 Infrastructure Setup - Destroy Script
# Safely destroys all infrastructure resources

set -euo pipefail

# Script directory and imports
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/scripts/utils.sh"

# Initialize logging
log_execution "destroy"

echo "=== Stage 02 Infrastructure Setup - Destroy ==="
echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo

# Load configuration from Stage 01 output
load_configuration

echo "=== Configuration Summary ==="
echo "Project: $PROJECT_PREFIX-$ENVIRONMENT"
echo "Region: $REGION"
echo "Domain: $DOMAIN"
echo

# Confirmation prompt
echo "⚠️  WARNING: This will destroy all Stage 02 infrastructure resources!"
echo "   - CloudFront distribution"
echo "   - Lambda function and logs"
echo "   - S3 bucket and all contents"
echo "   - Route 53 DNS records"
echo
read -p "Are you sure you want to continue? (yes/no): " -r
echo
if [[ ! $REPLY =~ ^yes$ ]]; then
    echo "Destroy operation cancelled."
    exit 0
fi

# Check if Terraform state exists
if [[ ! -f "terraform.tfstate" ]] && [[ ! -f ".terraform/terraform.tfstate" ]]; then
    echo "No Terraform state found. Attempting to initialize backend..."
    
    # Initialize backend to pull remote state
    terraform init \
      -backend-config="bucket=$BACKEND_BUCKET" \
      -backend-config="key=${PROJECT_PREFIX}/${ENVIRONMENT}/02-infra-setup/terraform.tfstate" \
      -backend-config="region=$REGION" \
      -backend-config="dynamodb_table=$BACKEND_TABLE" \
      -backend-config="encrypt=true"
fi

# Create terraform.tfvars file if it doesn't exist
if [[ ! -f "terraform.tfvars" ]]; then
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

# Default Lambda configuration
lambda_memory                 = 128
lambda_timeout                = 15

# Additional configuration
s3_bucket_name                = "${PROJECT_PREFIX}-${ENVIRONMENT}-static-assets"
cloudfront_price_class        = "PriceClass_100"
EOF
fi

# Show current state
echo "=== Checking Current Infrastructure ==="
terraform plan -destroy -var-file="terraform.tfvars"

echo
read -p "Proceed with destruction? (yes/no): " -r
echo
if [[ ! $REPLY =~ ^yes$ ]]; then
    echo "Destroy operation cancelled."
    exit 0
fi

# Empty S3 bucket first (required before destruction)
echo "=== Emptying S3 Bucket ==="
S3_BUCKET="${PROJECT_PREFIX}-${ENVIRONMENT}-static-assets"
if aws s3 ls "s3://$S3_BUCKET" >/dev/null 2>&1; then
    echo "Emptying S3 bucket: $S3_BUCKET"
    aws s3 rm "s3://$S3_BUCKET" --recursive
    echo "S3 bucket emptied successfully"
else
    echo "S3 bucket $S3_BUCKET not found or already empty"
fi

echo

# Destroy infrastructure
echo "=== Destroying Infrastructure ==="
terraform destroy \
  -var-file="terraform.tfvars" \
  -auto-approve

echo

# Clean up local files
echo "=== Cleaning Up Local Files ==="
rm -f terraform.tfvars
rm -f tfplan
rm -rf .terraform.lock.hcl

echo

# Remove output configuration
echo "=== Removing Output Configuration ==="
OUTPUT_FILE="output/${PROJECT_PREFIX}-config-${ENVIRONMENT}.json"
if [[ -f "$OUTPUT_FILE" ]]; then
    rm -f "$OUTPUT_FILE"
    echo "Output configuration removed: $OUTPUT_FILE"
fi

echo

echo "=== Destruction Summary ==="
echo "✅ Infrastructure destroyed successfully!"
echo
echo "All resources have been removed:"
echo "  ✅ CloudFront distribution"
echo "  ✅ Lambda function and logs"
echo "  ✅ S3 bucket and contents"
echo "  ✅ Route 53 DNS records"
echo "  ✅ IAM roles and policies"
echo "  ✅ CloudWatch log groups"
echo

echo "=== Post-Destruction Notes ==="
echo "- DNS propagation may take time to complete"
echo "- CloudWatch logs may be retained based on retention policy"
echo "- Terraform state has been destroyed"
echo

echo "Destruction completed at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"