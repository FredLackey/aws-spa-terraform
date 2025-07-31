#!/bin/bash

# 01-infra-foundation Stage - Deploy Script
# Purpose: Establish foundational AWS infrastructure for SPA deployment
# This stage creates cross-account IAM roles, manages SSL certificates, and validates infrastructure

set -euo pipefail

# Script directory and paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="${SCRIPT_DIR}/scripts"
CONFIG_DIR="${SCRIPT_DIR}/config"
INPUT_DIR="${SCRIPT_DIR}/input"
OUTPUT_DIR="${SCRIPT_DIR}/output"
LOGS_DIR="${SCRIPT_DIR}/logs"

# Source utility functions
source "${SCRIPTS_DIR}/utils.sh"
source "${SCRIPTS_DIR}/iam-operations.sh"
source "${SCRIPTS_DIR}/certificate-operations.sh"
source "${SCRIPTS_DIR}/validation-functions.sh"

# Initialize logging
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOG_FILE="${LOGS_DIR}/deploy-${TIMESTAMP}.log"
mkdir -p "${LOGS_DIR}"

# Function to display help
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Deploy the 01-infra-foundation stage for AWS SPA infrastructure.

This stage establishes foundational infrastructure including:
- Cross-account IAM roles and trust relationships
- SSL certificate discovery and creation with DNS validation  
- Infrastructure validation and testing
- Enhanced configuration output for stage 02

OPTIONS:
    --input-file FILE    Path to input configuration file
                        (default: auto-discover from ../00-discovery/output/)
    --help              Show this help message

EXECUTION PATTERN:
1. Input Preparation - Load and validate configuration from previous stage
2. Authentication - Validate AWS SSO sessions for both accounts
3. State Evaluation - Check existing resources and determine required actions
4. Infrastructure Operations - Create/update IAM roles and SSL certificates
5. Output Generation - Create enhanced configuration for next stage

EXAMPLES:
    # Auto-discover input from stage 00-discovery
    $0

    # Use specific input file
    $0 --input-file /path/to/config.json

NOTES:
- Requires valid AWS SSO sessions for both infrastructure and hosting profiles
- All operations are idempotent and safe to re-run
- Resources are tagged with Project and Environment from configuration
- Logs are written to logs/deploy-YYYYMMDD-HHMMSS.log

EOF
}

# Parse command line arguments
INPUT_FILE=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --input-file)
            INPUT_FILE="$2"
            shift 2
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown argument: $1"
            show_help
            exit 1
            ;;
    esac
done

# Main execution function
main() {
    log_info "Starting 01-infra-foundation stage deployment"
    log_info "Log file: ${LOG_FILE}"
    
    # Step 1: Input Preparation (must be first to load configuration)
    log_section "Step 1: Input Preparation"
    prepare_input_configuration
    
    # Step 2: Authentication Validation (now that we have profile names)
    log_section "Step 2: Authentication Validation"
    validate_aws_authentication
    
    # Step 3: State Evaluation  
    log_section "Step 3: State Evaluation"
    evaluate_current_state
    
    # Step 4: Infrastructure Operations
    log_section "Step 4: Infrastructure Operations"
    execute_infrastructure_operations
    
    # Step 5: Output Generation
    log_section "Step 5: Output Generation"
    generate_output_configuration
    
    log_success "01-infra-foundation stage deployment completed successfully"
    log_info "Enhanced configuration written to: ${OUTPUT_DIR}"
}

# Execute main function with logging
main "$@" 2>&1 | tee "${LOG_FILE}"