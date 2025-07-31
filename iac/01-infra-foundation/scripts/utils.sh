#!/bin/bash

# Utility Functions for 01-infra-foundation Stage
# Common logging, error handling, and configuration parsing functions

# Color codes for output formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Global variables
CONFIG_DATA=""
PROJECT_PREFIX=""
ENVIRONMENT=""
REGION=""
INFRASTRUCTURE_PROFILE=""
HOSTING_PROFILE=""
INFRASTRUCTURE_ACCOUNT_ID=""
HOSTING_ACCOUNT_ID=""

# Logging functions with structured output
log_info() {
    local message="$1"
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - ${message}"
}

log_success() {
    local message="$1"
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - ${message}"
}

log_warning() {
    local message="$1"
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - ${message}"
}

log_error() {
    local message="$1"
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - ${message}" >&2
}

log_section() {
    local section="$1"
    echo ""
    echo -e "${BLUE}===============================================================================${NC}"
    echo -e "${BLUE}${section}${NC}"
    echo -e "${BLUE}===============================================================================${NC}"
    echo ""
}

# Auto-discover input file from previous stage
auto_discover_input_file() {
    local discovery_output_dir="${SCRIPT_DIR}/../00-discovery/output"
    
    if [[ ! -d "${discovery_output_dir}" ]]; then
        log_error "Discovery output directory not found: ${discovery_output_dir}"
        return 1
    fi
    
    # Find the most recent .json file
    local input_file=$(find "${discovery_output_dir}" -name "*.json" -type f -exec ls -t {} + | head -n 1)
    
    if [[ -z "${input_file}" ]]; then
        log_error "No configuration files found in: ${discovery_output_dir}"
        return 1
    fi
    
    echo "${input_file}"
}

# Auto-discover configuration file for destruction from current stage output
auto_discover_destruction_input_file() {
    local current_stage_output_dir="${OUTPUT_DIR}"
    
    # If output directory exists and has files, prefer that
    if [[ -d "${current_stage_output_dir}" ]]; then
        local output_file=$(find "${current_stage_output_dir}" -name "*.json" -type f -exec ls -t {} + | head -n 1)
        
        if [[ -n "${output_file}" ]]; then
            log_info "Using current stage output configuration: ${output_file}"
            echo "${output_file}"
            return 0
        fi
    fi
    
    # Fallback to input directory
    if [[ -d "${INPUT_DIR}" ]]; then
        local input_file=$(find "${INPUT_DIR}" -name "*.json" -type f -exec ls -t {} + | head -n 1)
        
        if [[ -n "${input_file}" ]]; then
            log_info "Using current stage input configuration: ${input_file}"
            echo "${input_file}"
            return 0
        fi
    fi
    
    # Last resort: previous stage output
    log_warning "No configuration found in current stage, falling back to discovery"
    auto_discover_input_file
}

# Copy input file to current stage input directory
copy_input_file() {
    local source_file="$1"
    local filename=$(basename "${source_file}")
    local destination="${INPUT_DIR}/${filename}"
    
    log_info "Copying input file: ${source_file} -> ${destination}"
    
    if [[ ! -f "${source_file}" ]]; then
        log_error "Source file does not exist: ${source_file}"
        return 1
    fi
    
    mkdir -p "${INPUT_DIR}"
    cp "${source_file}" "${destination}"
    
    if [[ ! -f "${destination}" ]]; then
        log_error "Failed to copy input file to: ${destination}"
        return 1
    fi
    
    echo "${destination}"
}

# Load and validate configuration file
load_configuration() {
    local config_file="$1"
    
    log_info "Loading configuration from: ${config_file}"
    
    if [[ ! -f "${config_file}" ]]; then
        log_error "Configuration file not found: ${config_file}"
        return 1
    fi
    
    # Validate JSON format
    if ! jq empty "${config_file}" 2>/dev/null; then
        log_error "Invalid JSON format in configuration file: ${config_file}"
        return 1
    fi
    
    # Load configuration data
    CONFIG_DATA=$(cat "${config_file}")
    
    # Extract required fields with validation
    PROJECT_PREFIX=$(echo "${CONFIG_DATA}" | jq -r '.project.prefix // empty')
    ENVIRONMENT=$(echo "${CONFIG_DATA}" | jq -r '.project.environment // empty')
    REGION=$(echo "${CONFIG_DATA}" | jq -r '.project.region // empty')
    INFRASTRUCTURE_PROFILE=$(echo "${CONFIG_DATA}" | jq -r '.aws.infrastructure_profile // empty')
    HOSTING_PROFILE=$(echo "${CONFIG_DATA}" | jq -r '.aws.hosting_profile // empty')
    INFRASTRUCTURE_ACCOUNT_ID=$(echo "${CONFIG_DATA}" | jq -r '.aws.infrastructure_account_id // empty')
    HOSTING_ACCOUNT_ID=$(echo "${CONFIG_DATA}" | jq -r '.aws.hosting_account_id // empty')
    
    # Validate required fields
    local missing_fields=()
    [[ -z "${PROJECT_PREFIX}" ]] && missing_fields+=("project.prefix")
    [[ -z "${ENVIRONMENT}" ]] && missing_fields+=("project.environment")
    [[ -z "${REGION}" ]] && missing_fields+=("project.region")
    [[ -z "${INFRASTRUCTURE_PROFILE}" ]] && missing_fields+=("aws.infrastructure_profile")
    [[ -z "${HOSTING_PROFILE}" ]] && missing_fields+=("aws.hosting_profile")
    [[ -z "${INFRASTRUCTURE_ACCOUNT_ID}" ]] && missing_fields+=("aws.infrastructure_account_id")
    [[ -z "${HOSTING_ACCOUNT_ID}" ]] && missing_fields+=("aws.hosting_account_id")
    
    if [[ ${#missing_fields[@]} -gt 0 ]]; then
        log_error "Missing required configuration fields:"
        for field in "${missing_fields[@]}"; do
            log_error "  - ${field}"
        done
        return 1
    fi
    
    # Validate environment code
    local valid_environments=("sbx" "dev" "test" "uat" "stage" "mo" "prod")
    local env_valid=false
    for valid_env in "${valid_environments[@]}"; do
        if [[ "${ENVIRONMENT}" == "${valid_env}" ]]; then
            env_valid=true
            break
        fi
    done
    
    if [[ "${env_valid}" != "true" ]]; then
        log_error "Invalid environment code: ${ENVIRONMENT}"
        log_error "Valid environments: ${valid_environments[*]}"
        return 1
    fi
    
    log_success "Configuration loaded successfully"
    log_info "Project: ${PROJECT_PREFIX} | Environment: ${ENVIRONMENT} | Region: ${REGION}"
    log_info "Infrastructure Profile: ${INFRASTRUCTURE_PROFILE} | Hosting Profile: ${HOSTING_PROFILE}"
}

# Generate resource names following naming convention
generate_resource_name() {
    local resource_type="$1"
    
    case "${resource_type}" in
        "iam-role")
            echo "${PROJECT_PREFIX}/${ENVIRONMENT}"
            ;;
        "output-file")
            echo "${PROJECT_PREFIX}-config-${ENVIRONMENT}.json"
            ;;
        *)
            log_error "Unknown resource type: ${resource_type}"
            return 1
            ;;
    esac
}

# Log cleanup - remove old log files (keep last 10)
cleanup_old_logs() {
    local logs_dir="$1"
    local pattern="$2"  # e.g., "deploy-*.log"
    local keep_count=10
    
    if [[ -d "${logs_dir}" ]]; then
        log_info "Cleaning up old log files (keeping ${keep_count} most recent)"
        find "${logs_dir}" -name "${pattern}" -type f -exec ls -t {} + | tail -n +$((keep_count + 1)) | xargs -r rm -f
    fi
}

# Prepare input configuration - handles auto-discovery and validation
prepare_input_configuration() {
    local config_file=""
    
    if [[ -n "${INPUT_FILE}" ]]; then
        # Use specified input file
        config_file="${INPUT_FILE}"
        log_info "Using specified input file: ${config_file}"
    else
        # Auto-discover from previous stage
        log_info "Auto-discovering input file from previous stage"
        
        # Call auto_discover_input_file and capture only the last line (the file path)
        local discovery_output=$(auto_discover_input_file 2>&1)
        local discovery_status=$?
        local discovered_file=$(echo "${discovery_output}" | tail -n 1)
        
        if [[ ${discovery_status} -ne 0 ]]; then
            log_error "Failed to auto-discover input file"
            return 1
        fi
        
        # Copy to current stage input directory
        local copy_output=$(copy_input_file "${discovered_file}" 2>&1)
        local copy_status=$?
        config_file=$(echo "${copy_output}" | tail -n 1)
        
        if [[ ${copy_status} -ne 0 ]]; then
            log_error "Failed to copy input file"
            return 1
        fi
    fi
    
    # Load and validate configuration
    load_configuration "${config_file}"
    if [[ $? -ne 0 ]]; then
        log_error "Failed to load configuration"
        return 1
    fi
    
    log_success "Input configuration prepared successfully"
}

# Generate enhanced output configuration
generate_output_configuration() {
    local output_file="${OUTPUT_DIR}/$(generate_resource_name 'output-file')"
    
    log_info "Generating enhanced output configuration"
    
    # Create enhanced configuration combining input data with new infrastructure data
    local enhanced_config=$(echo "${CONFIG_DATA}" | jq --arg stage "01-infra-foundation" --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '
        .resource_naming.stage = $stage |
        .foundation = {
            "timestamp": $timestamp,
            "infrastructure_complete": true,
            "iam_roles": {
                "cross_account_role_arn": env.CROSS_ACCOUNT_ROLE_ARN // "",
                "validation_complete": (env.IAM_VALIDATION_COMPLETE // "false") == "true"
            },
            "ssl_certificate": {
                "certificate_arn": env.CERTIFICATE_ARN // "",
                "domain": env.CERTIFICATE_DOMAIN // "",
                "validation_complete": (env.CERTIFICATE_VALIDATION_COMPLETE // "false") == "true"
            }
        }
    ')
    
    # Ensure output directory exists
    mkdir -p "${OUTPUT_DIR}"
    
    # Write enhanced configuration
    echo "${enhanced_config}" | jq '.' > "${output_file}"
    
    if [[ $? -eq 0 ]]; then
        log_success "Enhanced configuration written to: ${output_file}"
    else
        log_error "Failed to write enhanced configuration to: ${output_file}"
        return 1
    fi
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Validate required tools
validate_required_tools() {
    local required_tools=("aws" "jq")
    local missing_tools=()
    
    for tool in "${required_tools[@]}"; do
        if ! command_exists "${tool}"; then
            missing_tools+=("${tool}")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools:"
        for tool in "${missing_tools[@]}"; do
            log_error "  - ${tool}"
        done
        return 1
    fi
    
    log_success "All required tools are available"
}

# Export functions for use in other scripts
export -f log_info log_success log_warning log_error log_section
export -f auto_discover_input_file auto_discover_destruction_input_file copy_input_file load_configuration
export -f generate_resource_name cleanup_old_logs
export -f prepare_input_configuration generate_output_configuration
export -f command_exists validate_required_tools