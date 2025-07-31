#!/bin/bash

# 01-infra-foundation Stage - Destroy Script
# Purpose: Clean up AWS resources created by the 01-infra-foundation stage
# This script removes IAM roles and certificates while preserving dependencies

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
LOG_FILE="${LOGS_DIR}/destroy-${TIMESTAMP}.log"
mkdir -p "${LOGS_DIR}"

# Function to display help
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Destroy resources created by the 01-infra-foundation stage.

This script removes:
- Cross-account IAM roles created for infrastructure foundation
- SSL certificates (if they were created by this stage)
- DNS validation records in Route 53

OPTIONS:
    --input-file FILE    Path to input configuration file
                        (default: auto-discover from output/ directory)
    --force             Skip dependency validation and force destruction
    --help              Show this help message

SAFETY FEATURES:
- Validates that no subsequent stages depend on current resources
- Provides detailed confirmation before destruction
- Logs all destruction actions for audit trail
- Skips destruction if resources are already removed

EXAMPLES:
    # Auto-discover configuration and perform safe destruction
    $0

    # Use specific configuration file
    $0 --input-file /path/to/config.json

    # Force destruction without dependency checks (use with caution)
    $0 --force

NOTES:
- Requires valid AWS SSO sessions for both infrastructure and hosting profiles
- Resources are only removed if they were created by this stage
- Shared resources (like existing certificates) are preserved
- All actions are logged for audit purposes

EOF
}

# Parse command line arguments
INPUT_FILE=""
FORCE_DESTROY=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --input-file)
            INPUT_FILE="$2"
            shift 2
            ;;
        --force)
            FORCE_DESTROY=true
            shift
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

# Function to check for dependent stages
check_stage_dependencies() {
    log_info "Checking for dependent stages that might be using current resources"
    
    local dependent_stages=("02-infra-setup" "03-app-build" "04-app-deploy")
    local has_dependencies=false
    
    for stage in "${dependent_stages[@]}"; do
        if [[ -d "${SCRIPT_DIR}/../${stage}" ]]; then
            if [[ -f "${SCRIPT_DIR}/../${stage}/output"/*.json ]]; then
                log_warning "Found evidence of stage ${stage} execution"
                has_dependencies=true
            fi
        fi
    done
    
    if [[ "${has_dependencies}" == "true" && "${FORCE_DESTROY}" != "true" ]]; then
        log_error "Dependent stages detected. Use --force to override dependency checks."
        exit 1
    fi
    
    if [[ "${FORCE_DESTROY}" == "true" ]]; then
        log_warning "Force mode enabled - skipping dependency validation"
    fi
}

# Main destruction function
main() {
    log_info "Starting 01-infra-foundation stage destruction"
    log_info "Log file: ${LOG_FILE}"
    
    # Input preparation (must be first to load configuration)
    log_section "Input Preparation"
    prepare_destruction_configuration
    
    # Authentication validation (now that we have profile names)
    log_section "Authentication Validation"
    validate_aws_authentication
    
    # Dependency validation
    log_section "Dependency Validation"
    check_stage_dependencies
    
    # State evaluation (now that configuration is loaded)
    log_section "State Evaluation"
    evaluate_destruction_state
    
    # Resource destruction
    log_section "Resource Destruction"
    execute_resource_destruction
    
    log_success "01-infra-foundation stage destruction completed successfully"
}

# Execute main function with logging
main "$@" 2>&1 | tee "${LOG_FILE}"