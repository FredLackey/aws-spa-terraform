#!/bin/bash

# Validation Functions for 01-infra-foundation Stage
# Resource validation and testing functions using AWS CLI

# Validate AWS SSO authentication for both accounts
validate_aws_authentication() {
    log_info "Validating AWS SSO authentication for both accounts"
    
    local auth_valid=true
    
    # Validate infrastructure account authentication
    log_info "Checking infrastructure account authentication (${INFRASTRUCTURE_PROFILE})"
    local infra_identity=$(aws sts get-caller-identity --profile "${INFRASTRUCTURE_PROFILE}" --output json 2>/dev/null)
    
    if [[ $? -eq 0 ]]; then
        local infra_account_id=$(echo "${infra_identity}" | jq -r '.Account')
        local infra_user_arn=$(echo "${infra_identity}" | jq -r '.Arn')
        
        if [[ "${infra_account_id}" == "${INFRASTRUCTURE_ACCOUNT_ID}" ]]; then
            log_success "Infrastructure account authentication valid"
            log_info "Identity: ${infra_user_arn}"
        else
            log_error "Infrastructure account ID mismatch. Expected: ${INFRASTRUCTURE_ACCOUNT_ID}, Found: ${infra_account_id}"
            auth_valid=false
        fi
    else
        log_error "Infrastructure account authentication failed"
        log_error "Please run: aws sso login --profile ${INFRASTRUCTURE_PROFILE}"
        auth_valid=false
    fi
    
    # Validate hosting account authentication
    log_info "Checking hosting account authentication (${HOSTING_PROFILE})"
    local hosting_identity=$(aws sts get-caller-identity --profile "${HOSTING_PROFILE}" --output json 2>/dev/null)
    
    if [[ $? -eq 0 ]]; then
        local hosting_account_id=$(echo "${hosting_identity}" | jq -r '.Account')
        local hosting_user_arn=$(echo "${hosting_identity}" | jq -r '.Arn')
        
        if [[ "${hosting_account_id}" == "${HOSTING_ACCOUNT_ID}" ]]; then
            log_success "Hosting account authentication valid"
            log_info "Identity: ${hosting_user_arn}"
        else
            log_error "Hosting account ID mismatch. Expected: ${HOSTING_ACCOUNT_ID}, Found: ${hosting_account_id}"
            auth_valid=false
        fi
    else
        log_error "Hosting account authentication failed"
        log_error "Please run: aws sso login --profile ${HOSTING_PROFILE}"
        auth_valid=false
    fi
    
    if [[ "${auth_valid}" == "true" ]]; then
        log_success "AWS SSO authentication validation completed successfully"
        return 0
    else
        log_error "AWS SSO authentication validation failed"
        return 1
    fi
}

# Check SSO session expiration
check_sso_session_expiration() {
    local profile="$1"
    
    log_info "Checking SSO session expiration for profile: ${profile}"
    
    # Try a simple API call to check if session is still valid
    local test_result=$(aws sts get-caller-identity --profile "${profile}" --output text --query 'Account' 2>/dev/null)
    
    if [[ $? -eq 0 && -n "${test_result}" ]]; then
        log_success "SSO session is valid for profile: ${profile}"
        return 0
    else
        log_warning "SSO session may be expired for profile: ${profile}"
        return 1
    fi
}

# Validate VPC accessibility in hosting account
validate_vpc_accessibility() {
    log_info "Validating VPC accessibility in hosting account"
    
    local vpc_id=$(echo "${CONFIG_DATA}" | jq -r '.vpc_id')
    if [[ -z "${vpc_id}" || "${vpc_id}" == "null" ]]; then
        log_error "VPC ID not found in configuration"
        return 1
    fi
    
    log_info "Validating VPC: ${vpc_id}"
    
    # Check VPC exists and is accessible from hosting account
    local vpc_info=$(aws ec2 describe-vpcs --vpc-ids "${vpc_id}" --profile "${HOSTING_PROFILE}" --output json 2>/dev/null)
    
    if [[ $? -eq 0 ]]; then
        local vpc_state=$(echo "${vpc_info}" | jq -r '.Vpcs[0].State')
        log_success "VPC found and accessible: ${vpc_id} (State: ${vpc_state})"
        
        if [[ "${vpc_state}" != "available" ]]; then
            log_warning "VPC state is not 'available': ${vpc_state}"
        fi
        
        return 0
    else
        log_error "VPC not accessible or does not exist: ${vpc_id}"
        return 1
    fi
}

# Test VPC permissions from infrastructure account
test_vpc_permissions_from_infrastructure() {
    log_info "Testing VPC permissions from infrastructure account"
    
    local vpc_id=$(echo "${CONFIG_DATA}" | jq -r '.vpc_id')
    if [[ -z "${vpc_id}" || "${vpc_id}" == "null" ]]; then
        log_error "VPC ID not found in configuration"
        return 1
    fi
    
    # Test if infrastructure account can access VPC information
    # This might fail if cross-account permissions aren't set up yet, which is expected
    local vpc_info=$(aws ec2 describe-vpcs --vpc-ids "${vpc_id}" --profile "${INFRASTRUCTURE_PROFILE}" --output json 2>/dev/null)
    
    if [[ $? -eq 0 ]]; then
        log_success "Infrastructure account can access VPC: ${vpc_id}"
        return 0
    else
        log_info "Infrastructure account cannot directly access VPC (this may be expected)"
        return 0  # Don't fail, as this might be normal before cross-account setup
    fi
}

# Validate hosted zone accessibility from infrastructure account
validate_hosted_zone_accessibility() {
    log_info "Validating hosted zone accessibility from infrastructure account"
    
    local domain=$(echo "${CONFIG_DATA}" | jq -r '.domain')
    if [[ -z "${domain}" || "${domain}" == "null" ]]; then
        log_error "Domain not found in configuration"
        return 1
    fi
    
    # Extract the zone name from the domain (get the root domain)
    local zone_name=""
    # Split domain into parts and get the last two parts (root domain)
    local domain_parts=($(echo "${domain}" | tr '.' ' '))
    local num_parts=${#domain_parts[@]}
    
    if [[ ${num_parts} -ge 2 ]]; then
        # Get last two parts (e.g., "briskhaven.com" from "thuapp.sbx.briskhaven.com")
        zone_name="${domain_parts[$((num_parts-2))]}.${domain_parts[$((num_parts-1))]}"
    else
        zone_name="${domain}"
    fi
    
    log_info "Validating hosted zone for: ${zone_name}"
    
    # Check hosted zone accessibility
    local hosted_zones=$(aws route53 list-hosted-zones --profile "${INFRASTRUCTURE_PROFILE}" --query "HostedZones[?Name=='${zone_name}.']" --output json 2>/dev/null)
    
    if [[ $? -eq 0 ]]; then
        local zone_count=$(echo "${hosted_zones}" | jq '. | length')
        
        if [[ "${zone_count}" -gt 0 ]]; then
            local zone_id=$(echo "${hosted_zones}" | jq -r '.[0].Id' | cut -d'/' -f3)
            log_success "Hosted zone accessible: ${zone_name} (ID: ${zone_id})"
            return 0
        else
            log_error "Hosted zone not found: ${zone_name}"
            return 1
        fi
    else
        log_error "Failed to access Route 53 hosted zones"
        return 1
    fi
}

# Test cross-account access after IAM role creation
test_cross_account_access() {
    log_info "Testing cross-account access functionality"
    
    if [[ -z "${CROSS_ACCOUNT_ROLE_ARN}" ]]; then
        log_warning "Cross-account role ARN not available, skipping cross-account access test"
        return 0
    fi
    
    log_info "Testing assume role: ${CROSS_ACCOUNT_ROLE_ARN}"
    
    # Test role assumption
    local external_id="${PROJECT_PREFIX}-${ENVIRONMENT}"
    local assume_result=$(aws sts assume-role \
        --role-arn "${CROSS_ACCOUNT_ROLE_ARN}" \
        --role-session-name "validation-test-${TIMESTAMP}" \
        --external-id "${external_id}" \
        --profile "${INFRASTRUCTURE_PROFILE}" \
        --query 'Credentials.AccessKeyId' \
        --output text 2>/dev/null)
    
    if [[ $? -eq 0 && -n "${assume_result}" && "${assume_result}" != "None" ]]; then
        log_success "Cross-account access test successful"
        return 0
    else
        log_error "Cross-account access test failed"
        return 1
    fi
}

# Validate SSL certificate accessibility from both accounts
validate_certificate_accessibility() {
    log_info "Validating SSL certificate accessibility from both accounts"
    
    if [[ -z "${CERTIFICATE_ARN}" ]]; then
        log_warning "Certificate ARN not available, skipping certificate accessibility test"
        return 0
    fi
    
    log_info "Testing certificate accessibility: ${CERTIFICATE_ARN}"
    
    # Test certificate access from hosting account
    local cert_status_hosting=$(aws acm describe-certificate --certificate-arn "${CERTIFICATE_ARN}" --profile "${HOSTING_PROFILE}" --query 'Certificate.Status' --output text 2>/dev/null)
    
    if [[ $? -eq 0 && -n "${cert_status_hosting}" ]]; then
        log_success "Certificate accessible from hosting account (Status: ${cert_status_hosting})"
    else
        log_error "Certificate not accessible from hosting account"
        return 1
    fi
    
    # Test certificate access from infrastructure account (may not work without cross-account permissions)
    local cert_status_infra=$(aws acm describe-certificate --certificate-arn "${CERTIFICATE_ARN}" --profile "${INFRASTRUCTURE_PROFILE}" --query 'Certificate.Status' --output text 2>/dev/null)
    
    if [[ $? -eq 0 && -n "${cert_status_infra}" ]]; then
        log_success "Certificate accessible from infrastructure account (Status: ${cert_status_infra})"
    else
        log_info "Certificate not directly accessible from infrastructure account (this may be expected)"
    fi
    
    return 0
}

# Comprehensive validation reporting
generate_validation_report() {
    log_info "Generating comprehensive validation report"
    
    local validation_results=()
    local overall_status="PASSED"
    
    # Collect validation results
    log_section "Validation Report Summary"
    
    # Authentication validation
    if validate_aws_authentication >/dev/null 2>&1; then
        validation_results+=("✅ AWS SSO Authentication: PASSED")
    else
        validation_results+=("❌ AWS SSO Authentication: FAILED")
        overall_status="FAILED"
    fi
    
    # VPC accessibility
    if validate_vpc_accessibility >/dev/null 2>&1; then
        validation_results+=("✅ VPC Accessibility: PASSED")
    else
        validation_results+=("❌ VPC Accessibility: FAILED")
        overall_status="FAILED"
    fi
    
    # Hosted zone accessibility
    if validate_hosted_zone_accessibility >/dev/null 2>&1; then
        validation_results+=("✅ Hosted Zone Accessibility: PASSED")
    else
        validation_results+=("❌ Hosted Zone Accessibility: FAILED")
        overall_status="FAILED"
    fi
    
    # Cross-account access (if role is available)
    # Try to get role ARN from global variable first, then from configuration
    local test_role_arn="${CROSS_ACCOUNT_ROLE_ARN}"
    
    if [[ -z "${test_role_arn}" ]]; then
        test_role_arn=$(echo "${CONFIG_DATA}" | jq -r '.foundation.iam_roles.cross_account_role_arn // empty')
    fi
    
    # If still no role ARN, try to construct it and check if it exists
    if [[ -z "${test_role_arn}" || "${test_role_arn}" == "null" ]]; then
        local role_name=$(generate_cross_account_role_name)
        local constructed_arn="arn:aws:iam::${HOSTING_ACCOUNT_ID}:role/${role_name}"
        
        # Verify the role actually exists before using the constructed ARN
        local role_exists_output=$(check_iam_role_exists "${HOSTING_PROFILE}" "${role_name}" 2>&1)
        local role_exists=$(echo "${role_exists_output}" | tail -n 1)
        
        if [[ "${role_exists}" == "exists" ]]; then
            test_role_arn="${constructed_arn}"
        fi
    fi
    
    if [[ -n "${test_role_arn}" && "${test_role_arn}" != "null" ]]; then
        # Temporarily set the variable for the test function
        local original_arn="${CROSS_ACCOUNT_ROLE_ARN}"
        export CROSS_ACCOUNT_ROLE_ARN="${test_role_arn}"
        
        if test_cross_account_access >/dev/null 2>&1; then
            validation_results+=("✅ Cross-Account Access: PASSED")
        else
            validation_results+=("❌ Cross-Account Access: FAILED")
            overall_status="FAILED"
        fi
        
        # Restore original value
        export CROSS_ACCOUNT_ROLE_ARN="${original_arn}"
    else
        validation_results+=("⚠️  Cross-Account Access: SKIPPED (Role not available)")
    fi
    
    # Certificate accessibility (if certificate is available)
    if [[ -n "${CERTIFICATE_ARN}" ]]; then
        if validate_certificate_accessibility >/dev/null 2>&1; then
            validation_results+=("✅ Certificate Accessibility: PASSED")
        else
            validation_results+=("❌ Certificate Accessibility: FAILED")
            overall_status="FAILED"
        fi
    else
        validation_results+=("⚠️  Certificate Accessibility: SKIPPED (Certificate not available)")
    fi
    
    # Display results
    echo ""
    for result in "${validation_results[@]}"; do
        echo "${result}"
    done
    echo ""
    
    if [[ "${overall_status}" == "PASSED" ]]; then
        log_success "Overall validation status: PASSED"
        return 0
    else
        log_error "Overall validation status: FAILED"
        return 1
    fi
}

# Evaluate current state of resources
evaluate_current_state() {
    log_info "Evaluating current state of AWS resources"
    
    # Check if required tools are available
    validate_required_tools
    if [[ $? -ne 0 ]]; then
        log_error "Required tools validation failed"
        return 1
    fi
    
    # Infrastructure readiness (authentication already validated in step 2)
    validate_vpc_accessibility
    validate_hosted_zone_accessibility
    
    log_success "Current state evaluation completed"
}

# State evaluation for destruction
evaluate_destruction_state() {
    log_info "Evaluating state for resource destruction"
    
    # Check what resources exist that could be cleaned up
    local role_name=$(generate_cross_account_role_name)
    local role_exists_output=$(check_iam_role_exists "${HOSTING_PROFILE}" "${role_name}" 2>&1)
    local role_exists=$(echo "${role_exists_output}" | tail -n 1)
    
    if [[ "${role_exists}" == "exists" ]]; then
        log_info "Found IAM role that can be cleaned up: ${role_name}"
        
        # Get the role ARN for validation
        local role_arn=$(get_iam_role_arn "${HOSTING_PROFILE}" "${role_name}")
        if [[ -n "${role_arn}" ]]; then
            log_info "IAM role ARN: ${role_arn}"
            
            # Check if this matches the role from output configuration
            local config_role_arn=$(echo "${CONFIG_DATA}" | jq -r '.foundation.iam_roles.cross_account_role_arn // empty')
            if [[ -n "${config_role_arn}" && "${role_arn}" == "${config_role_arn}" ]]; then
                log_success "IAM role matches configuration - will be cleaned up"
            elif [[ -n "${config_role_arn}" ]]; then
                log_warning "IAM role ARN mismatch. Found: ${role_arn}, Expected: ${config_role_arn}"
            fi
        fi
    else
        log_info "No IAM role found to clean up: ${role_name}"
        
        # Check if configuration indicates there should be a role
        local config_role_arn=$(echo "${CONFIG_DATA}" | jq -r '.foundation.iam_roles.cross_account_role_arn // empty')
        if [[ -n "${config_role_arn}" ]]; then
            log_warning "Configuration indicates IAM role should exist: ${config_role_arn}"
            log_warning "Role may have been deleted manually or creation may have failed"
        fi
    fi
    
    # Check for certificates
    local domain=$(echo "${CONFIG_DATA}" | jq -r '.domain // empty')
    if [[ -n "${domain}" ]]; then
        local search_output=$(search_existing_certificates "${HOSTING_PROFILE}" "${domain}" 2>&1)
        local search_status=$?
        local cert_arn=$(echo "${search_output}" | tail -n 1)
        
        if [[ ${search_status} -eq 0 && -n "${cert_arn}" && "${cert_arn}" =~ ^arn:aws:acm: ]]; then
            log_info "Found certificate for domain: ${domain}"
            log_info "Certificate ARN: ${cert_arn}"
            
            # Check if this matches the certificate from output configuration
            local config_cert_arn=$(echo "${CONFIG_DATA}" | jq -r '.foundation.ssl_certificate.certificate_arn // empty')
            if [[ -n "${config_cert_arn}" && "${cert_arn}" == "${config_cert_arn}" ]]; then
                log_success "Certificate matches configuration"
            elif [[ -n "${config_cert_arn}" ]]; then
                log_warning "Certificate ARN mismatch. Found: ${cert_arn}, Expected: ${config_cert_arn}"
            fi
            
            log_warning "Certificates will NOT be automatically deleted for safety"
        else
            log_info "No certificate found for domain: ${domain}"
            
            # Check if configuration indicates there should be a certificate
            local config_cert_arn=$(echo "${CONFIG_DATA}" | jq -r '.foundation.ssl_certificate.certificate_arn // empty')
            if [[ -n "${config_cert_arn}" ]]; then
                log_warning "Configuration indicates certificate should exist: ${config_cert_arn}"
                log_warning "Certificate may have been deleted manually or creation may have failed"
            fi
        fi
    fi
    
    log_success "Destruction state evaluation completed"
}

# Main function for infrastructure operations
execute_infrastructure_operations() {
    log_info "Executing infrastructure operations"
    
    # Step 1: Manage cross-account IAM roles
    log_info "Step 1: Managing cross-account IAM roles"
    manage_cross_account_iam_roles
    if [[ $? -ne 0 ]]; then
        log_error "Cross-account IAM role management failed"
        return 1
    fi
    
    # Step 2: Manage SSL certificates
    log_info "Step 2: Managing SSL certificates"
    manage_ssl_certificates
    if [[ $? -ne 0 ]]; then
        log_error "SSL certificate management failed"
        return 1
    fi
    
    # Step 3: Run comprehensive validation
    log_info "Step 3: Running comprehensive validation"
    
    # Ensure CROSS_ACCOUNT_ROLE_ARN is available for validation
    # If not set, try to get it from configuration or construct it
    if [[ -z "${CROSS_ACCOUNT_ROLE_ARN}" ]]; then
        local role_name=$(generate_cross_account_role_name)
        CROSS_ACCOUNT_ROLE_ARN="arn:aws:iam::${HOSTING_ACCOUNT_ID}:role/${role_name}"
        export CROSS_ACCOUNT_ROLE_ARN
        log_info "Setting CROSS_ACCOUNT_ROLE_ARN for validation: ${CROSS_ACCOUNT_ROLE_ARN}"
    fi
    
    # Add a brief delay to account for AWS eventual consistency
    log_info "Allowing time for AWS resource propagation..."
    sleep 5
    
    generate_validation_report
    if [[ $? -ne 0 ]]; then
        log_error "Validation failed"
        return 1
    fi
    
    log_success "Infrastructure operations completed successfully"
}

# Prepare destruction configuration
prepare_destruction_configuration() {
    log_info "Preparing configuration for destruction"
    
    local config_file=""
    
    if [[ -n "${INPUT_FILE}" ]]; then
        # Use specified input file
        config_file="${INPUT_FILE}"
        log_info "Using specified input file: ${config_file}"
    else
        # Auto-discover from current stage output (for destruction operations)
        log_info "Auto-discovering configuration file for destruction"
        
        # Call auto_discover_destruction_input_file and capture the result
        local discovery_output=$(auto_discover_destruction_input_file 2>&1)
        local discovery_status=$?
        local discovered_file=$(echo "${discovery_output}" | tail -n 1)
        
        if [[ ${discovery_status} -ne 0 ]]; then
            log_error "Failed to auto-discover configuration file"
            return 1
        fi
        
        config_file="${discovered_file}"
    fi
    
    # Load and validate configuration
    load_configuration "${config_file}"
    if [[ $? -ne 0 ]]; then
        log_error "Failed to load configuration"
        return 1
    fi
    
    log_success "Destruction configuration prepared"
}

# Execute resource destruction
execute_resource_destruction() {
    log_info "Executing resource destruction"
    
    # Clean up IAM resources
    cleanup_iam_resources
    if [[ $? -ne 0 ]]; then
        log_error "IAM resource cleanup failed"
        return 1
    fi
    
    # Clean up certificate resources (informational only)
    cleanup_certificate_resources
    if [[ $? -ne 0 ]]; then
        log_error "Certificate resource cleanup failed"
        return 1
    fi
    
    log_success "Resource destruction completed successfully"
}

# Export functions for use in main scripts
export -f validate_aws_authentication check_sso_session_expiration
export -f validate_vpc_accessibility test_vpc_permissions_from_infrastructure
export -f validate_hosted_zone_accessibility test_cross_account_access
export -f validate_certificate_accessibility generate_validation_report
export -f evaluate_current_state evaluate_destruction_state
export -f execute_infrastructure_operations prepare_destruction_configuration
export -f execute_resource_destruction