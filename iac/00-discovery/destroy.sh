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

# Usage function
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Required Arguments:
  -e, --environment        Environment (SBX, DEV, TEST, UAT, STAGE, MO, PROD)
  -r, --region            AWS region (e.g., us-east-1, us-west-2)

Optional Arguments:
  --help                 Show this help message

Examples:
  $0 -e DEV -r us-east-1
  $0 --environment PROD --region us-west-2

NOTE: This stage only cleans up local configuration files.
No AWS resources are destroyed since none are created by the discovery stage.

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
    mkdir -p "$SCRIPT_DIR/logs"
    echo "[$timestamp] [$level] $message" >> "$SCRIPT_DIR/logs/destroy-$(date +%Y%m%d).log"
}

# Check if stage is configured
check_stage_state() {
    local env_lower="${ENVIRONMENT,,}"
    
    # We need to find the output file, but we don't know the project prefix from arguments
    # Look for any files matching the pattern
    local output_files
    output_files=($(find "$SCRIPT_DIR/output" -name "*-config-${env_lower}.json" 2>/dev/null || true))
    
    log INFO "Checking if stage $STAGE_NAME is configured for environment $ENVIRONMENT"
    
    # Check if configuration files exist
    if [[ ${#output_files[@]} -eq 0 ]]; then
        log INFO "Stage $STAGE_NAME does not appear to be configured for environment $ENVIRONMENT"
        log INFO "No configuration files found. Nothing to clean up."
        exit 0
    fi
    
    log INFO "Stage appears to be configured. Configuration files found:"
    for file in "${output_files[@]}"; do
        log INFO "  - $(basename "$file")"
    done
    
    return 0
}

# Check for dependent stages
check_dependencies() {
    log INFO "Checking for dependent stages that might be affected by cleaning up $STAGE_NAME"
    
    # Check for subsequent stage directories
    local dependent_stages=()
    for stage_dir in "$SCRIPT_DIR"/../0[1-9]-*; do
        if [[ -d "$stage_dir" ]]; then
            dependent_stages+=("$(basename "$stage_dir")")
        fi
    done
    
    if [[ ${#dependent_stages[@]} -gt 0 ]]; then
        log WARN "Found dependent stages that may be affected:"
        for stage in "${dependent_stages[@]}"; do
            log WARN "  - $stage"
        done
        log WARN ""
        log WARN "Cleaning up $STAGE_NAME configuration may require reconfiguration of these dependent stages."
        log WARN "Consider cleaning up dependent stages first, in reverse order."
        
        echo -e "${YELLOW}Do you want to continue? (y/N):${NC} "
        read -r confirmation
        if [[ ! "$confirmation" =~ ^[Yy]$ ]]; then
            log INFO "Cleanup cancelled by user"
            exit 0
        fi
    fi
}

# Clean up local files
cleanup_local_files() {
    local env_lower="${ENVIRONMENT,,}"
    
    log INFO "Cleaning up local configuration files for environment: $ENVIRONMENT"
    
    # Find and remove output files for this environment
    local output_files
    output_files=($(find "$SCRIPT_DIR/output" -name "*-config-${env_lower}.json" 2>/dev/null || true))
    
    if [[ ${#output_files[@]} -gt 0 ]]; then
        for output_file in "${output_files[@]}"; do
            rm -f "$output_file"
            log INFO "Removed output file: $(basename "$output_file")"
        done
    else
        log INFO "No output files found for environment $ENVIRONMENT"
    fi
    
    # Remove empty output directory if it exists and is empty
    if [[ -d "$SCRIPT_DIR/output" ]] && [[ ! "$(ls -A "$SCRIPT_DIR/output")" ]]; then
        rmdir "$SCRIPT_DIR/output"
        log INFO "Removed empty output directory"
    fi
    
    log INFO "Local file cleanup completed"
}

# Main execution function
main() {
    log INFO "Starting $STAGE_NAME cleanup for environment: $ENVIRONMENT"
    log INFO "NOTE: This stage only cleans up local configuration files - no AWS resources are destroyed"
    
    # Parse and validate arguments
    parse_arguments "$@"
    validate_arguments
    
    # Check if stage is configured
    check_stage_state
    
    # Check dependencies
    check_dependencies
    
    # Clean up local files
    cleanup_local_files
    
    log INFO "$STAGE_NAME cleanup completed"
    log INFO "Local configuration files have been cleaned up"
    log INFO ""
    log INFO "To reconfigure this stage, run:"
    log INFO "  ./deploy.sh -e $ENVIRONMENT -r $REGION [other required arguments]"
}

# Run main function with all arguments
main "$@"