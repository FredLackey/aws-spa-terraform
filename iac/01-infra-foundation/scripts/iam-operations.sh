#!/bin/bash

# IAM Operations for 01-infra-foundation Stage
# Functions for cross-account IAM role discovery, creation, and validation

# Global variables for IAM operations
CROSS_ACCOUNT_ROLE_ARN=""
IAM_VALIDATION_COMPLETE="false"

# Check if IAM role exists in the specified account
check_iam_role_exists() {
    local profile="$1"
    local role_name="$2"
    
    log_info "Checking if IAM role exists: ${role_name} (profile: ${profile})"
    
    # Try to get the role, redirect stderr to suppress error output for non-existent roles
    local role_info=$(aws iam get-role --role-name "${role_name}" --profile "${profile}" 2>/dev/null)
    
    if [[ $? -eq 0 ]]; then
        log_success "IAM role found: ${role_name}"
        echo "exists"
    else
        log_info "IAM role not found: ${role_name}"
        echo "not_exists"
    fi
}

# Get IAM role ARN
get_iam_role_arn() {
    local profile="$1"
    local role_name="$2"
    
    local role_arn=$(aws iam get-role --role-name "${role_name}" --profile "${profile}" --query 'Role.Arn' --output text 2>/dev/null)
    
    if [[ $? -eq 0 && -n "${role_arn}" ]]; then
        echo "${role_arn}"
    else
        echo ""
    fi
}

# Generate cross-account role name
generate_cross_account_role_name() {
    echo "${PROJECT_PREFIX}-${ENVIRONMENT}-cross-account-role"
}

# Load trust policy template and substitute variables
generate_trust_policy() {
    local infrastructure_account_id="$1"
    
    cat << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::${infrastructure_account_id}:root"
            },
            "Action": "sts:AssumeRole",
            "Condition": {
                "StringEquals": {
                    "sts:ExternalId": "${PROJECT_PREFIX}-${ENVIRONMENT}"
                }
            }
        }
    ]
}
EOF
}

# Load IAM permissions policy template
generate_iam_permissions_policy() {
    cat << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "acm:DescribeCertificate",
                "acm:ListCertificates",
                "acm:RequestCertificate",
                "acm:AddTagsToCertificate",
                "route53:GetHostedZone",
                "route53:ListHostedZones",
                "route53:ChangeResourceRecordSets",
                "route53:GetChange",
                "ec2:DescribeVpcs",
                "ec2:DescribeSubnets",
                "ec2:DescribeSecurityGroups"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}

# Compare trust policies to detect mismatches
compare_trust_policies() {
    local existing_policy="$1"
    local required_policy="$2"
    
    # Normalize JSON formatting and compare
    local existing_normalized=$(echo "${existing_policy}" | jq -S '.')
    local required_normalized=$(echo "${required_policy}" | jq -S '.')
    
    if [[ "${existing_normalized}" == "${required_normalized}" ]]; then
        echo "match"
    else
        echo "mismatch"
    fi
}

# Create IAM role with trust policy
create_iam_role() {
    local profile="$1"
    local role_name="$2"
    local trust_policy="$3"
    local description="Cross-account role for ${PROJECT_PREFIX} ${ENVIRONMENT} infrastructure"
    
    log_info "Creating IAM role: ${role_name} (profile: ${profile})"
    
    # Create temporary file for trust policy
    local trust_policy_file=$(mktemp)
    echo "${trust_policy}" > "${trust_policy_file}"
    
    # Create the role
    local create_result=$(aws iam create-role \
        --role-name "${role_name}" \
        --assume-role-policy-document "file://${trust_policy_file}" \
        --description "${description}" \
        --profile "${profile}" 2>&1)
    
    local create_status=$?
    rm -f "${trust_policy_file}"
    
    if [[ ${create_status} -eq 0 ]]; then
        log_success "IAM role created successfully: ${role_name}"
        
        # Add tags to the role
        tag_iam_role "${profile}" "${role_name}"
        
        return 0
    else
        log_error "Failed to create IAM role: ${role_name}"
        log_error "Error: ${create_result}"
        return 1
    fi
}

# Update IAM role trust policy
update_iam_role_trust_policy() {
    local profile="$1"
    local role_name="$2"
    local trust_policy="$3"
    
    log_info "Updating trust policy for IAM role: ${role_name}"
    
    # Create temporary file for trust policy
    local trust_policy_file=$(mktemp)
    echo "${trust_policy}" > "${trust_policy_file}"
    
    # Update the trust policy
    local update_result=$(aws iam update-assume-role-policy \
        --role-name "${role_name}" \
        --policy-document "file://${trust_policy_file}" \
        --profile "${profile}" 2>&1)
    
    local update_status=$?
    rm -f "${trust_policy_file}"
    
    if [[ ${update_status} -eq 0 ]]; then
        log_success "Trust policy updated successfully for: ${role_name}"
        return 0
    else
        log_error "Failed to update trust policy for: ${role_name}"
        log_error "Error: ${update_result}"
        return 1
    fi
}

# Attach permissions policy to IAM role
attach_iam_role_policy() {
    local profile="$1"
    local role_name="$2"
    local policy_name="${PROJECT_PREFIX}-${ENVIRONMENT}-permissions"
    
    log_info "Attaching permissions policy to IAM role: ${role_name}"
    
    # Create temporary file for permissions policy
    local permissions_policy=$(generate_iam_permissions_policy)
    local policy_file=$(mktemp)
    echo "${permissions_policy}" > "${policy_file}"
    
    # Put the role policy
    local attach_result=$(aws iam put-role-policy \
        --role-name "${role_name}" \
        --policy-name "${policy_name}" \
        --policy-document "file://${policy_file}" \
        --profile "${profile}" 2>&1)
    
    local attach_status=$?
    rm -f "${policy_file}"
    
    if [[ ${attach_status} -eq 0 ]]; then
        log_success "Permissions policy attached successfully to: ${role_name}"
        return 0
    else
        log_error "Failed to attach permissions policy to: ${role_name}"
        log_error "Error: ${attach_result}"
        return 1
    fi
}

# Test cross-account role assumption
test_role_assumption() {
    local infrastructure_profile="$1"
    local role_arn="$2"
    local external_id="${PROJECT_PREFIX}-${ENVIRONMENT}"
    
    log_info "Testing cross-account role assumption: ${role_arn}"
    
    # Try to assume the role
    local assume_result=$(aws sts assume-role \
        --role-arn "${role_arn}" \
        --role-session-name "test-session-${TIMESTAMP}" \
        --external-id "${external_id}" \
        --profile "${infrastructure_profile}" \
        --query 'Credentials.AccessKeyId' \
        --output text 2>&1)
    
    if [[ $? -eq 0 && -n "${assume_result}" && "${assume_result}" != "None" ]]; then
        log_success "Cross-account role assumption test successful"
        return 0
    else
        log_error "Cross-account role assumption test failed"
        log_error "Error: ${assume_result}"
        return 1
    fi
}

# Tag IAM role with mandatory tags
tag_iam_role() {
    local profile="$1"
    local role_name="$2"
    
    log_info "Tagging IAM role: ${role_name}"
    
    # Create tags
    local tag_result=$(aws iam tag-role \
        --role-name "${role_name}" \
        --tags "Key=Project,Value=${PROJECT_PREFIX}" "Key=Environment,Value=${ENVIRONMENT}" \
        --profile "${profile}" 2>&1)
    
    if [[ $? -eq 0 ]]; then
        log_success "IAM role tagged successfully: ${role_name}"
        return 0
    else
        log_error "Failed to tag IAM role: ${role_name}"
        log_error "Error: ${tag_result}"
        return 1
    fi
}

# Validate IAM role tags
validate_iam_role_tags() {
    local profile="$1"
    local role_name="$2"
    
    log_info "Validating IAM role tags: ${role_name}"
    
    # Get role tags
    local tags=$(aws iam list-role-tags --role-name "${role_name}" --profile "${profile}" --query 'Tags' --output json 2>/dev/null)
    
    if [[ $? -ne 0 ]]; then
        log_error "Failed to get IAM role tags for: ${role_name}"
        return 1
    fi
    
    # Check for required tags
    local project_tag=$(echo "${tags}" | jq -r '.[] | select(.Key=="Project") | .Value // empty')
    local environment_tag=$(echo "${tags}" | jq -r '.[] | select(.Key=="Environment") | .Value // empty')
    
    local validation_passed=true
    
    if [[ "${project_tag}" != "${PROJECT_PREFIX}" ]]; then
        log_error "Missing or incorrect Project tag. Expected: ${PROJECT_PREFIX}, Found: ${project_tag}"
        validation_passed=false
    fi
    
    if [[ "${environment_tag}" != "${ENVIRONMENT}" ]]; then
        log_error "Missing or incorrect Environment tag. Expected: ${ENVIRONMENT}, Found: ${environment_tag}"
        validation_passed=false
    fi
    
    if [[ "${validation_passed}" == "true" ]]; then
        log_success "IAM role tags validation passed"
        return 0
    else
        log_error "IAM role tags validation failed"
        return 1
    fi
}

# Main function to manage cross-account IAM roles
manage_cross_account_iam_roles() {
    log_info "Managing cross-account IAM roles"
    
    local role_name=$(generate_cross_account_role_name)
    local trust_policy=$(generate_trust_policy "${INFRASTRUCTURE_ACCOUNT_ID}")
    
    # Check if role exists in hosting account
    local role_exists=$(check_iam_role_exists "${HOSTING_PROFILE}" "${role_name}")
    
    if [[ "${role_exists}" == "exists" ]]; then
        log_info "IAM role already exists, validating configuration"
        
        # Get existing trust policy
        local existing_trust_policy=$(aws iam get-role --role-name "${role_name}" --profile "${HOSTING_PROFILE}" --query 'Role.AssumeRolePolicyDocument' --output json 2>/dev/null)
        
        # Compare with required trust policy
        local policy_comparison=$(compare_trust_policies "${existing_trust_policy}" "${trust_policy}")
        
        if [[ "${policy_comparison}" == "mismatch" ]]; then
            log_warning "Trust policy mismatch detected, updating"
            update_iam_role_trust_policy "${HOSTING_PROFILE}" "${role_name}" "${trust_policy}"
            if [[ $? -ne 0 ]]; then
                log_error "Failed to update trust policy"
                return 1
            fi
        else
            log_success "Trust policy is correct"
        fi
        
        # Ensure permissions policy is attached
        attach_iam_role_policy "${HOSTING_PROFILE}" "${role_name}"
        
    else
        log_info "IAM role does not exist, creating"
        
        # Create the role
        create_iam_role "${HOSTING_PROFILE}" "${role_name}" "${trust_policy}"
        if [[ $? -ne 0 ]]; then
            log_error "Failed to create IAM role"
            return 1
        fi
        
        # Attach permissions policy
        attach_iam_role_policy "${HOSTING_PROFILE}" "${role_name}"
        if [[ $? -ne 0 ]]; then
            log_error "Failed to attach permissions policy"
            return 1
        fi
    fi
    
    # Get role ARN
    CROSS_ACCOUNT_ROLE_ARN=$(get_iam_role_arn "${HOSTING_PROFILE}" "${role_name}")
    if [[ -z "${CROSS_ACCOUNT_ROLE_ARN}" ]]; then
        log_error "Failed to get IAM role ARN"
        return 1
    fi
    
    log_info "Cross-account role ARN: ${CROSS_ACCOUNT_ROLE_ARN}"
    
    # Validate tags
    validate_iam_role_tags "${HOSTING_PROFILE}" "${role_name}"
    if [[ $? -ne 0 ]]; then
        log_error "IAM role tag validation failed"
        return 1
    fi
    
    # Test role assumption
    test_role_assumption "${INFRASTRUCTURE_PROFILE}" "${CROSS_ACCOUNT_ROLE_ARN}"
    if [[ $? -ne 0 ]]; then
        log_error "Cross-account role assumption test failed"
        return 1
    fi
    
    # Export variables for use in other functions
    export CROSS_ACCOUNT_ROLE_ARN
    export IAM_VALIDATION_COMPLETE="true"
    
    log_success "Cross-account IAM role management completed successfully"
}

# Function to clean up IAM resources during destruction
cleanup_iam_resources() {
    local role_name=$(generate_cross_account_role_name)
    
    log_info "Cleaning up IAM resources"
    
    # Check if role exists (fix output capture issue)
    local role_exists_output=$(check_iam_role_exists "${HOSTING_PROFILE}" "${role_name}" 2>&1)
    local role_exists=$(echo "${role_exists_output}" | tail -n 1)
    
    if [[ "${role_exists}" == "exists" ]]; then
        log_info "Removing IAM role: ${role_name}"
        
        # Remove attached policies first
        local policy_name="${PROJECT_PREFIX}-${ENVIRONMENT}-permissions"
        aws iam delete-role-policy --role-name "${role_name}" --policy-name "${policy_name}" --profile "${HOSTING_PROFILE}" 2>/dev/null
        
        # Delete the role
        local delete_result=$(aws iam delete-role --role-name "${role_name}" --profile "${HOSTING_PROFILE}" 2>&1)
        
        if [[ $? -eq 0 ]]; then
            log_success "IAM role deleted successfully: ${role_name}"
        else
            log_error "Failed to delete IAM role: ${role_name}"
            log_error "Error: ${delete_result}"
            return 1
        fi
    else
        log_info "IAM role does not exist, nothing to clean up"
    fi
    
    log_success "IAM resource cleanup completed"
}

# Export functions for use in main scripts
export -f check_iam_role_exists get_iam_role_arn generate_cross_account_role_name
export -f generate_trust_policy generate_iam_permissions_policy compare_trust_policies
export -f create_iam_role update_iam_role_trust_policy attach_iam_role_policy
export -f test_role_assumption tag_iam_role validate_iam_role_tags
export -f manage_cross_account_iam_roles cleanup_iam_resources