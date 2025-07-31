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

Optional Arguments:
  --help                 Show this help message

Examples:
  $0 -e DEV -r us-east-1 -p myapp -i infra -h hosting -d dev-app.example.com
  $0 --environment PROD --region us-west-2 --project-prefix myapp --infra-profile infrastructure --hosting-profile hosting --domain app.example.com

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
}

# Log function
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        INFO)
            echo -e "${GREEN}[INFO]${NC} $message"
            ;;
        WARN)
            echo -e "${YELLOW}[WARN]${NC} $message"
            ;;
        ERROR)
            echo -e "${RED}[ERROR]${NC} $message"
            ;;
        DEBUG)
            echo -e "${BLUE}[DEBUG]${NC} $message"
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
    
    # Extract account ID
    local account_id
    account_id=$(aws sts get-caller-identity --profile "$profile" --query 'Account' --output text)
    
    if [[ -z "$account_id" ]]; then
        log ERROR "Failed to extract account ID for profile '$profile'"
        exit 1
    fi
    
    log INFO "Successfully validated $profile_type account: $account_id"
    echo "$account_id"
}

# Validate Route 53 hosted zone (REQUIRED)
validate_hosted_zone() {
    local domain=$1
    local profile=$2
    
    # Extract top-level domain (everything after the first dot)
    local tld
    if [[ "$domain" == *.* ]]; then
        tld="${domain#*.}"
    else
        tld="$domain"
    fi
    
    log INFO "Validating required Route 53 hosted zone for domain: $tld"
    
    # Check if hosted zone exists
    local zone_id
    zone_id=$(aws route53 list-hosted-zones --profile "$profile" \
        --query "HostedZones[?Name=='${tld}.'].Id" --output text 2>/dev/null || true)
    
    if [[ -n "$zone_id" && "$zone_id" != "None" ]]; then
        log INFO "✓ Found required Route 53 hosted zone for $tld: $zone_id"
        return 0
    else
        log ERROR "✗ REQUIRED Route 53 hosted zone NOT found for $tld in infrastructure account"
        log ERROR "The hosted zone for $tld must exist before deployment can proceed"
        log ERROR "Subsequent stages will need to create DNS records and cannot continue without this zone"
        log ERROR ""
        log ERROR "To resolve this issue:"
        log ERROR "1. Create a hosted zone for $tld in the infrastructure account"
        log ERROR "2. Ensure proper DNS delegation is configured"
        log ERROR "3. Re-run this discovery stage"
        return 1
    fi
}

# Generate resource names for future stages
generate_resource_names() {
    local account_id=$1
    local env_lower="${ENVIRONMENT,,}"
    local prefix_lower="${PROJECT_PREFIX,,}"
    
    # These are the names that future stages will use
    TERRAFORM_BUCKET="terraform-state-${account_id}-${env_lower}"
    TERRAFORM_TABLE="terraform-locks-${account_id}-${env_lower}"
    
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
    "environment": "${ENVIRONMENT,,}",
    "region": "$REGION"
  },
  "aws": {
    "infrastructure_profile": "$INFRA_PROFILE",
    "hosting_profile": "$HOSTING_PROFILE",
    "infrastructure_account_id": "$infra_account_id",
    "hosting_account_id": "$hosting_account_id"
  },
  "domain": "$DOMAIN",
  "terraform": {
    "backend_bucket": "$TERRAFORM_BUCKET",
    "backend_table": "$TERRAFORM_TABLE"
  },
  "resource_naming": {
    "local_path": "$PROJECT_PREFIX/${ENVIRONMENT,,}",
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
    log INFO "Checking if stage $STAGE_NAME is already configured for environment $ENVIRONMENT"
    
    # Check if output file exists and is recent
    if [[ -f "$OUTPUT_FILE" ]]; then
        log INFO "Stage appears to already be configured. Output file exists: $OUTPUT_FILE"
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
    
    # Check stage state
    check_stage_state
    
    # Validate AWS profiles and extract account IDs
    log INFO "Validating AWS profiles and SSO sessions"
    INFRA_ACCOUNT_ID=$(validate_aws_profile "$INFRA_PROFILE" "infrastructure")
    HOSTING_ACCOUNT_ID=$(validate_aws_profile "$HOSTING_PROFILE" "hosting")
    
    # Generate resource names that future stages will use
    generate_resource_names "$INFRA_ACCOUNT_ID"
    
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
    log INFO ""
    log INFO "Next steps:"
    log INFO "  1. Review generated configuration file: $OUTPUT_FILE"
    log INFO "  2. Proceed to stage 01-infra-foundation"
}

# Run main function with all arguments
main "$@"