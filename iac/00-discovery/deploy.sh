#!/bin/bash

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAGE_NAME="00-discovery"

# Initialize variables
ENVIRONMENT=""
REGION=""
PROJECT_PREFIX=""
INFRA_PROFILE=""
HOSTING_PROFILE=""
DOMAIN=""
VPC_ID=""

# Usage function
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Required Arguments:
  -e, --environment        Environment (SBX, DEV, TEST, UAT, STAGE, MO, PROD)
  -r, --region            AWS region (e.g., us-east-1, us-west-2)
  -p, --project-prefix    Project prefix for resource naming
  -i, --infra-profile     AWS profile for infrastructure account
  -h, --hosting-profile   AWS profile for hosting account
  -d, --domain            Fully qualified domain name for the application
  -v, --vpc-id            Target VPC ID for deployment

Optional Arguments:
  --help                 Show this help message

Examples:
  $0 -e DEV -r us-east-1 -p myapp -i infra -h hosting -d dev-app.example.com -v vpc-12345abcd
  $0 --environment PROD --region us-west-2 --project-prefix myapp --infra-profile infrastructure --hosting-profile hosting --domain app.example.com --vpc-id vpc-67890efgh

EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -e|--environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -r|--region)
                REGION="$2"
                shift 2
                ;;
            -p|--project-prefix)
                PROJECT_PREFIX="$2"
                shift 2
                ;;
            -i|--infra-profile)
                INFRA_PROFILE="$2"
                shift 2
                ;;
            -h|--hosting-profile)
                HOSTING_PROFILE="$2"
                shift 2
                ;;
            -d|--domain)
                DOMAIN="$2"
                shift 2
                ;;
            -v|--vpc-id)
                VPC_ID="$2"
                shift 2
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                echo -e "${RED}Error: Unknown argument '$1'${NC}"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Validate required arguments
validate_arguments() {
    local missing_args=()
    
    [[ -z "$ENVIRONMENT" ]] && missing_args+=("--environment")
    [[ -z "$REGION" ]] && missing_args+=("--region")
    [[ -z "$PROJECT_PREFIX" ]] && missing_args+=("--project-prefix")
    [[ -z "$INFRA_PROFILE" ]] && missing_args+=("--infra-profile")
    [[ -z "$HOSTING_PROFILE" ]] && missing_args+=("--hosting-profile")
    [[ -z "$DOMAIN" ]] && missing_args+=("--domain")
    [[ -z "$VPC_ID" ]] && missing_args+=("--vpc-id")
    
    if [[ ${#missing_args[@]} -gt 0 ]]; then
        echo -e "${RED}Error: Missing required arguments: ${missing_args[*]}${NC}"
        show_usage
        exit 1
    fi
    
    # Validate environment
    case "$ENVIRONMENT" in
        SBX|DEV|TEST|UAT|STAGE|MO|PROD)
            ;;
        *)
            echo -e "${RED}Error: Invalid environment '$ENVIRONMENT'. Must be one of: SBX, DEV, TEST, UAT, STAGE, MO, PROD${NC}"
            exit 1
            ;;
    esac
    
    # Validate project prefix format (alphanumeric, lowercase)
    if [[ ! "$PROJECT_PREFIX" =~ ^[a-z0-9]+$ ]]; then
        echo -e "${RED}Error: Project prefix must be lowercase alphanumeric characters only${NC}"
        exit 1
    fi
    
    # Validate VPC ID format
    if [[ ! "$VPC_ID" =~ ^vpc-[a-f0-9]{8,17}$ ]]; then
        echo -e "${RED}Error: VPC ID must be in format vpc-xxxxxxxx (8-17 hex characters)${NC}"
        exit 1
    fi
}

# Log function - all output goes to stderr to avoid contaminating command substitution
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        INFO)
            echo -e "${GREEN}[INFO]${NC} $message" >&2
            ;;
        WARN)
            echo -e "${YELLOW}[WARN]${NC} $message" >&2
            ;;
        ERROR)
            echo -e "${RED}[ERROR]${NC} $message" >&2
            ;;
        DEBUG)
            echo -e "${BLUE}[DEBUG]${NC} $message" >&2
            ;;
    esac
    
    # Also log to file
    echo "[$timestamp] [$level] $message" >> "$SCRIPT_DIR/logs/deploy-$(date +%Y%m%d).log"
}

# Validate AWS profile and SSO session
validate_aws_profile() {
    local profile=$1
    local profile_type=$2
    
    log INFO "Validating AWS profile: $profile ($profile_type account)"
    
    # Test current session
    if ! aws sts get-caller-identity --profile "$profile" &>/dev/null; then
        log WARN "AWS profile '$profile' session invalid or expired. Attempting SSO login..."
        
        # Attempt SSO login
        if ! aws sso login --profile "$profile"; then
            log ERROR "Failed to login with AWS profile '$profile'"
            exit 1
        fi
        
        # Re-test session
        if ! aws sts get-caller-identity --profile "$profile" &>/dev/null; then
            log ERROR "AWS profile '$profile' still invalid after SSO login attempt"
            exit 1
        fi
    fi
    
    # Extract account ID (redirect stderr to avoid contamination)
    local account_id
    account_id=$(aws sts get-caller-identity --profile "$profile" --query 'Account' --output text 2>/dev/null)
    
    if [[ -z "$account_id" ]]; then
        log ERROR "Failed to extract account ID for profile '$profile'"
        exit 1
    fi
    
    log INFO "Successfully validated $profile_type account: $account_id"
    
    # Return only the account ID on stdout
    printf "%s" "$account_id"
}

# Validate Route 53 hosted zone (REQUIRED)
validate_hosted_zone() {
    local domain=$1
    local profile=$2
    
    log INFO "Validating required Route 53 hosted zone for domain: $domain"
    
    # Build array of domains to check, from most specific to least specific
    local domains_to_check=()
    local current_domain="$domain"
    
    # Add the full domain first
    domains_to_check+=("$current_domain")
    
    # Extract parent domains (remove subdomains one by one)
    while [[ "$current_domain" == *.* ]]; do
        current_domain="${current_domain#*.}"
        domains_to_check+=("$current_domain")
    done
    
    # Check each domain level for a hosted zone
    for check_domain in "${domains_to_check[@]}"; do
        log INFO "Checking for hosted zone: $check_domain"
        
        local zone_id
        zone_id=$(aws route53 list-hosted-zones --profile "$profile" \
            --query "HostedZones[?Name=='${check_domain}.'].Id" --output text 2>/dev/null || true)
        
        if [[ -n "$zone_id" && "$zone_id" != "None" ]]; then
            log INFO "✓ Found required Route 53 hosted zone for $check_domain: $zone_id"
            if [[ "$check_domain" != "$domain" ]]; then
                log INFO "  Domain $domain will use parent hosted zone: $check_domain"
            fi
            return 0
        fi
    done
    
    # If we get here, no hosted zone was found at any level
    log ERROR "✗ REQUIRED Route 53 hosted zone NOT found for $domain or any parent domains"
    log ERROR "Checked domains: ${domains_to_check[*]}"
    log ERROR "At least one hosted zone must exist before deployment can proceed"
    log ERROR "Subsequent stages will need to create DNS records and cannot continue without a hosted zone"
    log ERROR ""
    log ERROR "To resolve this issue:"
    log ERROR "1. Create a hosted zone for one of these domains in the infrastructure account:"
    for check_domain in "${domains_to_check[@]}"; do
        log ERROR "   - $check_domain"
    done
    log ERROR "2. Ensure proper DNS delegation is configured"
    log ERROR "3. Re-run this discovery stage"
    return 1
}

# Generate resource names for future stages
generate_resource_names() {
    local infra_account_id=$1
    local hosting_account_id=$2
    local env_lower=$(echo "$ENVIRONMENT" | tr '[:upper:]' '[:lower:]')
    local prefix_lower=$(echo "$PROJECT_PREFIX" | tr '[:upper:]' '[:lower:]')
    
    # These are the names that future stages will use
    TERRAFORM_BUCKET="terraform-state-${infra_account_id}-${env_lower}"
    TERRAFORM_TABLE="terraform-locks-${infra_account_id}-${env_lower}"
    
    # Output file for next stage (includes project prefix for archival identification)
    OUTPUT_FILE="$SCRIPT_DIR/output/${prefix_lower}-config-${env_lower}.json"
    
    log DEBUG "Generated future Terraform bucket: $TERRAFORM_BUCKET"
    log DEBUG "Generated future Terraform table: $TERRAFORM_TABLE"
    log DEBUG "Generated output file: $OUTPUT_FILE"
}


# Generate configuration output for next stage
generate_config_output() {
    local infra_account_id=$1
    local hosting_account_id=$2
    
    log INFO "Generating configuration output file: $OUTPUT_FILE"
    
    # Ensure output directory exists
    mkdir -p "$(dirname "$OUTPUT_FILE")"
    
    # Generate JSON configuration
    cat > "$OUTPUT_FILE" << EOF
{
  "project": {
    "prefix": "$PROJECT_PREFIX",
    "environment": "$(echo "$ENVIRONMENT" | tr '[:upper:]' '[:lower:]')",
    "region": "$REGION"
  },
  "aws": {
    "infrastructure_profile": "$INFRA_PROFILE",
    "hosting_profile": "$HOSTING_PROFILE",
    "infrastructure_account_id": "$infra_account_id",
    "hosting_account_id": "$hosting_account_id"
  },
  "domain": "$DOMAIN",
  "vpc_id": "$VPC_ID",
  "terraform": {
    "backend_bucket": "$TERRAFORM_BUCKET",
    "backend_table": "$TERRAFORM_TABLE"
  },
  "resource_naming": {
    "local_path": "$PROJECT_PREFIX/$(echo "$ENVIRONMENT" | tr '[:upper:]' '[:lower:]')",
    "stage": "$STAGE_NAME"
  },
  "discovery": {
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "validation_complete": true
  }
}
EOF
    
    log INFO "Configuration output generated successfully"
}

# Check if stage is already configured
check_stage_state() {
    local output_file=$1
    
    log INFO "Checking if stage $STAGE_NAME is already configured for environment $ENVIRONMENT"
    
    # Check if output file exists and is recent
    if [[ -f "$output_file" ]]; then
        log INFO "Stage appears to already be configured. Output file exists: $output_file"
        log INFO "Re-running configuration with current parameters"
    else
        log INFO "Stage not yet configured. Proceeding with initial setup"
    fi
}

# Main execution function
main() {
    log INFO "Starting $STAGE_NAME discovery for environment: $ENVIRONMENT"
    log INFO "Project: $PROJECT_PREFIX, Region: $REGION"
    log INFO "NOTE: This stage only validates and collects configuration - no AWS resources will be created"
    
    # Ensure log directory exists
    mkdir -p "$SCRIPT_DIR/logs"
    
    # Parse and validate arguments
    parse_arguments "$@"
    validate_arguments
    
    # Validate AWS profiles and extract account IDs
    log INFO "Validating AWS profiles and SSO sessions"
    INFRA_ACCOUNT_ID=$(validate_aws_profile "$INFRA_PROFILE" "infrastructure")
    HOSTING_ACCOUNT_ID=$(validate_aws_profile "$HOSTING_PROFILE" "hosting")
    
    # Generate resource names that future stages will use
    generate_resource_names "$INFRA_ACCOUNT_ID" "$HOSTING_ACCOUNT_ID"
    
    # Check stage state now that we have the output file path
    check_stage_state "$OUTPUT_FILE"
    
    # Validate hosted zone (REQUIRED - blocking)
    log INFO "Validating required Route 53 hosted zone"
    if ! validate_hosted_zone "$DOMAIN" "$INFRA_PROFILE"; then
        log ERROR "Discovery failed: Required Route 53 hosted zone validation failed"
        log ERROR "Deployment cannot proceed without the hosted zone"
        exit 1
    fi
    
    # Generate output configuration file
    generate_config_output "$INFRA_ACCOUNT_ID" "$HOSTING_ACCOUNT_ID"
    
    log INFO "$STAGE_NAME discovery completed successfully"
    log INFO "Configuration file generated: $OUTPUT_FILE"
    log INFO ""
    log INFO "Discovery Summary:"
    log INFO "  - Infrastructure Account: $INFRA_ACCOUNT_ID (profile: $INFRA_PROFILE)"
    log INFO "  - Hosting Account: $HOSTING_ACCOUNT_ID (profile: $HOSTING_PROFILE)"
    log INFO "  - Project: $PROJECT_PREFIX"
    log INFO "  - Environment: $ENVIRONMENT"
    log INFO "  - Region: $REGION"
    log INFO "  - Application Domain: $DOMAIN"
    log INFO "  - VPC ID: $VPC_ID"
    log INFO ""
    log INFO "Next steps:"
    log INFO "  1. Review generated configuration file: $OUTPUT_FILE"
    log INFO "  2. Proceed to stage 01-infra-foundation"
}

# Run main function with all arguments
main "$@"