#!/bin/bash

# Stage 02 Infrastructure Setup - Utility Functions
# Configuration parsing and validation functions

set -euo pipefail

# Global variables for configuration
CONFIG_FILE=""
PROJECT_PREFIX=""
ENVIRONMENT=""
REGION=""
CERTIFICATE_ARN=""
VPC_ID=""
CROSS_ACCOUNT_ROLE_ARN=""
DOMAIN=""
BACKEND_BUCKET=""
BACKEND_TABLE=""

# Function to find and load configuration file
load_configuration() {
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local stage_dir="$(dirname "$script_dir")"
    local input_dir="$stage_dir/input"
    
    # Find the configuration file (should be only one)
    CONFIG_FILE=$(find "$input_dir" -name "*-config-*.json" | head -n 1)
    
    if [[ -z "$CONFIG_FILE" || ! -f "$CONFIG_FILE" ]]; then
        echo "ERROR: No configuration file found in $input_dir"
        echo "Expected format: {project-prefix}-config-{environment}.json"
        exit 1
    fi
    
    echo "INFO: Using configuration file: $CONFIG_FILE"
    
    # Validate JSON format
    if ! jq . "$CONFIG_FILE" > /dev/null 2>&1; then
        echo "ERROR: Invalid JSON format in configuration file: $CONFIG_FILE"
        exit 1
    fi
    
    # Extract configuration values
    PROJECT_PREFIX=$(jq -r '.project.prefix // empty' "$CONFIG_FILE")
    ENVIRONMENT=$(jq -r '.project.environment // empty' "$CONFIG_FILE")
    REGION=$(jq -r '.project.region // empty' "$CONFIG_FILE")
    CERTIFICATE_ARN=$(jq -r '.foundation.ssl_certificate.certificate_arn // empty' "$CONFIG_FILE")
    VPC_ID=$(jq -r '.vpc_id // empty' "$CONFIG_FILE")
    CROSS_ACCOUNT_ROLE_ARN=$(jq -r '.foundation.iam_roles.cross_account_role_arn // empty' "$CONFIG_FILE")
    DOMAIN=$(jq -r '.domain // empty' "$CONFIG_FILE")
    BACKEND_BUCKET=$(jq -r '.terraform.backend_bucket // empty' "$CONFIG_FILE")
    BACKEND_TABLE=$(jq -r '.terraform.backend_table // empty' "$CONFIG_FILE")
    
    # Validate required fields
    validate_configuration
}

# Function to validate configuration data
validate_configuration() {
    local errors=()
    
    [[ -z "$PROJECT_PREFIX" ]] && errors+=("project.prefix")
    [[ -z "$ENVIRONMENT" ]] && errors+=("project.environment")
    [[ -z "$REGION" ]] && errors+=("project.region")
    [[ -z "$CERTIFICATE_ARN" ]] && errors+=("foundation.ssl_certificate.certificate_arn")
    [[ -z "$VPC_ID" ]] && errors+=("vpc_id")
    [[ -z "$CROSS_ACCOUNT_ROLE_ARN" ]] && errors+=("foundation.iam_roles.cross_account_role_arn")
    [[ -z "$DOMAIN" ]] && errors+=("domain")
    [[ -z "$BACKEND_BUCKET" ]] && errors+=("terraform.backend_bucket")
    [[ -z "$BACKEND_TABLE" ]] && errors+=("terraform.backend_table")
    
    if [[ ${#errors[@]} -gt 0 ]]; then
        echo "ERROR: Missing required configuration fields:"
        printf "  - %s\n" "${errors[@]}"
        exit 1
    fi
    
    echo "INFO: Configuration validation successful"
    echo "  Project: $PROJECT_PREFIX-$ENVIRONMENT"
    echo "  Region: $REGION"
    echo "  Domain: $DOMAIN"
    echo "  VPC ID: $VPC_ID"
}

# Function to get configuration value by JSON path
get_config_value() {
    local json_path="$1"
    jq -r "$json_path // empty" "$CONFIG_FILE"
}

# Function to validate that environment and region are NOT provided as parameters
validate_no_env_region_params() {
    local params=("$@")
    
    for param in "${params[@]}"; do
        case "$param" in
            --environment|-e|--region|-r)
                echo "ERROR: Environment and region parameters are not allowed"
                echo "These values are automatically discovered from Stage 01 output"
                echo "Current values from configuration:"
                echo "  Environment: $ENVIRONMENT"
                echo "  Region: $REGION"
                exit 1
                ;;
        esac
    done
}

# Function to parse command line parameters for memory and timeout
parse_lambda_params() {
    local memory="128"
    local timeout="15"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --memory|-m)
                memory="$2"
                shift 2
                ;;
            --timeout|-t)
                timeout="$2"
                shift 2
                ;;
            --environment|-e|--region|-r)
                echo "ERROR: Environment and region parameters are not allowed"
                echo "These values are automatically discovered from Stage 01 output"
                exit 1
                ;;
            *)
                echo "ERROR: Unknown parameter: $1"
                echo "Allowed parameters: --memory/-m, --timeout/-t"
                exit 1
                ;;
        esac
    done
    
    # Validate memory (must be between 128MB and 10240MB)
    if ! [[ "$memory" =~ ^[0-9]+$ ]] || [[ "$memory" -lt 128 ]] || [[ "$memory" -gt 10240 ]]; then
        echo "ERROR: Memory must be between 128 and 10240 MB"
        exit 1
    fi
    
    # Validate timeout (must be between 1 and 900 seconds)
    if ! [[ "$timeout" =~ ^[0-9]+$ ]] || [[ "$timeout" -lt 1 ]] || [[ "$timeout" -gt 900 ]]; then
        echo "ERROR: Timeout must be between 1 and 900 seconds"
        exit 1
    fi
    
    export LAMBDA_MEMORY="$memory"
    export LAMBDA_TIMEOUT="$timeout"
    
    echo "INFO: Lambda configuration:"
    echo "  Memory: ${LAMBDA_MEMORY}MB"
    echo "  Timeout: ${LAMBDA_TIMEOUT}s"
}

# Function to generate output configuration file
generate_output_config() {
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local stage_dir="$(dirname "$script_dir")"
    local output_dir="$stage_dir/output"
    local output_file="${output_dir}/${PROJECT_PREFIX}-config-${ENVIRONMENT}.json"
    
    # Ensure output directory exists
    mkdir -p "$output_dir"
    
    # Get CloudFront distribution domain and Lambda function URL from Terraform outputs
    local cloudfront_domain=""
    local lambda_function_url=""
    
    if command -v terraform >/dev/null 2>&1; then
        if [[ -f "${stage_dir}/terraform.tfstate" ]]; then
            cloudfront_domain=$(terraform -chdir="$stage_dir" output -raw cloudfront_domain_name 2>/dev/null || echo "")
            lambda_function_url=$(terraform -chdir="$stage_dir" output -raw lambda_function_url 2>/dev/null || echo "")
        fi
    fi
    
    # Create enhanced configuration with Stage 02 data
    jq --arg cloudfront_domain "$cloudfront_domain" \
       --arg lambda_function_url "$lambda_function_url" \
       --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
       --arg stage "02-infra-setup" \
       '. + {
         "resource_naming": (.resource_naming + {"stage": $stage}),
         "setup": {
           "timestamp": $timestamp,
           "infrastructure_complete": true,
           "cloudfront": {
             "distribution_domain": $cloudfront_domain,
             "validation_complete": ($cloudfront_domain != "")
           },
           "lambda": {
             "function_url": $lambda_function_url,
             "validation_complete": ($lambda_function_url != "")
           }
         }
       }' "$CONFIG_FILE" > "$output_file"
    
    echo "INFO: Output configuration generated: $output_file"
}

# Function to log script execution
log_execution() {
    local script_name="$1"
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local stage_dir="$(dirname "$script_dir")"
    local log_dir="$stage_dir/logs"
    local log_file="${log_dir}/${script_name}-$(date +%Y%m%d-%H%M%S).log"
    
    mkdir -p "$log_dir"
    echo "INFO: Logging to: $log_file"
    exec > >(tee -a "$log_file") 2>&1
}

# Export functions for use in other scripts
export -f load_configuration
export -f validate_configuration
export -f get_config_value
export -f validate_no_env_region_params
export -f parse_lambda_params
export -f generate_output_config
export -f log_execution