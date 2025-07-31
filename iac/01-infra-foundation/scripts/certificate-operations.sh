#!/bin/bash

# Certificate Operations for 01-infra-foundation Stage
# Functions for SSL certificate discovery, creation, and DNS validation

# Global variables for certificate operations
CERTIFICATE_ARN=""
CERTIFICATE_DOMAIN=""
CERTIFICATE_VALIDATION_COMPLETE="false"

# Search for existing SSL certificates by exact domain match
search_existing_certificates() {
    local profile="$1"
    local domain="$2"
    
    log_info "Searching for existing SSL certificates for domain: ${domain} (profile: ${profile})"
    
    # List all certificates and filter by exact domain match
    local cert_list=$(aws acm list-certificates --profile "${profile}" --query 'CertificateSummaryList[?DomainName==`'"${domain}"'`]' --output json 2>/dev/null)
    
    if [[ $? -ne 0 ]]; then
        log_error "Failed to list certificates"
        return 1
    fi
    
    # Check if any certificates were found
    local cert_count=$(echo "${cert_list}" | jq '. | length')
    
    if [[ "${cert_count}" -gt 0 ]]; then
        # Get the first certificate (should only be one for exact match)
        local cert_arn=$(echo "${cert_list}" | jq -r '.[0].CertificateArn')
        log_success "Found existing certificate: ${cert_arn}"
        echo "${cert_arn}"
    else
        log_info "No existing certificates found for domain: ${domain}"
        echo ""
    fi
}

# Get certificate status and validation details
get_certificate_status() {
    local profile="$1"
    local cert_arn="$2"
    
    log_info "Getting certificate status: ${cert_arn}" >&2
    
    local cert_details=$(aws acm describe-certificate --certificate-arn "${cert_arn}" --profile "${profile}" --output json 2>/dev/null)
    
    if [[ $? -ne 0 ]]; then
        log_error "Failed to get certificate details" >&2
        return 1
    fi
    
    local status=$(echo "${cert_details}" | jq -r '.Certificate.Status')
    echo "${status}"
}

# Validate certificate domain matches exactly (no wildcards)
validate_exact_domain_match() {
    local certificate_domain="$1"
    local required_domain="$2"
    
    log_info "Validating exact domain match: ${certificate_domain} vs ${required_domain}"
    
    # Check for exact match (no wildcards)
    if [[ "${certificate_domain}" == "${required_domain}" ]]; then
        log_success "Exact domain match confirmed"
        echo "exact_match"
    elif [[ "${certificate_domain}" == "*."* ]]; then
        log_info "Certificate is wildcard, looking for exact match"
        echo "wildcard"
    else
        log_info "Domain mismatch"
        echo "mismatch"
    fi
}

# Request new SSL certificate with DNS validation
request_ssl_certificate() {
    local profile="$1"
    local domain="$2"
    
    log_info "Requesting new SSL certificate for domain: ${domain} (profile: ${profile})"
    
    # Request certificate with DNS validation
    local request_result=$(aws acm request-certificate \
        --domain-name "${domain}" \
        --validation-method DNS \
        --profile "${profile}" \
        --query 'CertificateArn' \
        --output text 2>&1)
    
    if [[ $? -eq 0 && -n "${request_result}" ]]; then
        log_success "Certificate request submitted: ${request_result}"
        echo "${request_result}"
    else
        log_error "Failed to request certificate"
        log_error "Error: ${request_result}"
        return 1
    fi
}

# Get DNS validation records for certificate with retry logic
get_dns_validation_records() {
    local profile="$1"
    local cert_arn="$2"
    local max_attempts=12  # 12 attempts = 2 minutes with 10-second intervals
    local attempt=1
    
    log_info "Getting DNS validation records for certificate: ${cert_arn}" >&2
    
    while [[ ${attempt} -le ${max_attempts} ]]; do
        log_info "Attempt ${attempt}/${max_attempts} to retrieve DNS validation records" >&2
        
        # Check if validation records are available
        local validation_records=$(aws acm describe-certificate \
            --certificate-arn "${cert_arn}" \
            --profile "${profile}" \
            --query 'Certificate.DomainValidationOptions[0].ResourceRecord' \
            --output json 2>/dev/null)
        
        # Check if we got valid JSON that's not null
        if [[ $? -eq 0 && "${validation_records}" != "null" && -n "${validation_records}" ]]; then
            # Validate it's actually valid JSON
            if echo "${validation_records}" | jq empty 2>/dev/null; then
                log_success "DNS validation records retrieved successfully" >&2
                echo "${validation_records}"
                return 0
            fi
        fi
        
        log_info "DNS validation records not ready yet, waiting 10 seconds..." >&2
        sleep 10
        ((attempt++))
    done
    
    # If we get here, we've exhausted all attempts
    log_error "Failed to get DNS validation records after ${max_attempts} attempts" >&2
    
    # Let's see what the full certificate info looks like for debugging
    local full_cert_info=$(aws acm describe-certificate \
        --certificate-arn "${cert_arn}" \
        --profile "${profile}" \
        --output json 2>/dev/null)
    
    log_error "Full certificate info for debugging:" >&2
    log_error "${full_cert_info}" >&2
    
    return 1
}

# Get hosted zone ID for domain
get_hosted_zone_id() {
    local profile="$1"
    local domain="$2"
    
    log_info "Getting hosted zone ID for domain: ${domain}" >&2
    
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
    
    log_info "Looking for hosted zone: ${zone_name}" >&2
    
    local hosted_zone_id=$(aws route53 list-hosted-zones \
        --profile "${profile}" \
        --query "HostedZones[?Name=='${zone_name}.'].Id" \
        --output text 2>/dev/null | cut -d'/' -f3)
    
    if [[ -n "${hosted_zone_id}" && "${hosted_zone_id}" != "None" ]]; then
        log_success "Found hosted zone ID: ${hosted_zone_id}" >&2
        echo "${hosted_zone_id}"
    else
        log_error "Hosted zone not found for: ${zone_name}" >&2
        return 1
    fi
}

# Create DNS validation record in Route 53
create_dns_validation_record() {
    local profile="$1"
    local hosted_zone_id="$2"
    local validation_record="$3"
    
    log_info "Creating DNS validation record in Route 53" >&2
    log_info "Raw validation record input: ${validation_record}" >&2
    
    # Validate that validation_record is valid JSON
    if ! echo "${validation_record}" | jq empty 2>/dev/null; then
        log_error "Invalid JSON in validation record: ${validation_record}" >&2
        return 1
    fi
    
    # Parse validation record details
    local record_name=$(echo "${validation_record}" | jq -r '.Name // empty')
    local record_value=$(echo "${validation_record}" | jq -r '.Value // empty')
    local record_type=$(echo "${validation_record}" | jq -r '.Type // empty')
    
    # Validate required fields
    if [[ -z "${record_name}" || -z "${record_value}" || -z "${record_type}" ]]; then
        log_error "Missing required DNS record fields" >&2
        log_error "Name: '${record_name}', Type: '${record_type}', Value: '${record_value}'" >&2
        return 1
    fi
    
    log_info "DNS Record - Name: ${record_name}, Type: ${record_type}, Value: ${record_value}" >&2
    
    # Create change batch for Route 53
    local change_batch=$(cat << EOF
{
    "Changes": [
        {
            "Action": "UPSERT",
            "ResourceRecordSet": {
                "Name": "${record_name}",
                "Type": "${record_type}",
                "TTL": 300,
                "ResourceRecords": [
                    {
                        "Value": "${record_value}"
                    }
                ]
            }
        }
    ]
}
EOF
)
    
    # Create temporary file for change batch
    local change_batch_file=$(mktemp)
    echo "${change_batch}" > "${change_batch_file}"
    
    # Submit the change
    log_info "Submitting DNS change to hosted zone: ${hosted_zone_id}" >&2
    local change_result=$(aws route53 change-resource-record-sets \
        --hosted-zone-id "${hosted_zone_id}" \
        --change-batch "file://${change_batch_file}" \
        --profile "${profile}" \
        --query 'ChangeInfo.Id' \
        --output text 2>&1)
    
    local change_status=$?
    rm -f "${change_batch_file}"
    
    if [[ ${change_status} -eq 0 && -n "${change_result}" && "${change_result}" != "None" ]]; then
        log_success "DNS validation record created: ${change_result}" >&2
        echo "${change_result}"
    else
        log_error "Failed to create DNS validation record" >&2
        log_error "AWS CLI exit code: ${change_status}" >&2
        log_error "AWS CLI output: ${change_result}" >&2
        return 1
    fi
}

# Wait for DNS change to propagate
wait_for_dns_change() {
    local profile="$1"
    local change_id="$2"
    local max_wait=300  # 5 minutes
    local wait_interval=30
    local elapsed=0
    
    log_info "Waiting for DNS change to propagate: ${change_id}"
    
    while [[ ${elapsed} -lt ${max_wait} ]]; do
        # Check if change_id is empty
        if [[ -z "${change_id}" ]]; then
            log_error "Change ID is empty, cannot check status"
            return 1
        fi
        
        local change_status=$(aws route53 get-change \
            --id "${change_id}" \
            --profile "${profile}" \
            --query 'ChangeInfo.Status' \
            --output text 2>/dev/null)
        
        # Check for AWS CLI errors
        if [[ $? -ne 0 ]]; then
            log_error "Failed to check DNS change status for ID: ${change_id}"
            return 1
        fi
        
        if [[ "${change_status}" == "INSYNC" ]]; then
            log_success "DNS change propagated successfully"
            return 0
        fi
        
        if [[ -z "${change_status}" ]]; then
            log_warning "Empty change status returned, change ID may be invalid: ${change_id}"
        fi
        
        log_info "DNS change status: ${change_status}, waiting ${wait_interval} seconds..."
        sleep ${wait_interval}
        elapsed=$((elapsed + wait_interval))
    done
    
    log_warning "DNS change propagation timeout reached, but continuing..."
    return 0  # Don't fail the entire process for DNS propagation timeout
}

# Wait for certificate validation to complete
wait_for_certificate_validation() {
    local profile="$1"
    local cert_arn="$2"
    local max_wait=1800  # 30 minutes
    local wait_interval=60
    local elapsed=0
    
    log_info "Waiting for certificate validation to complete: ${cert_arn}"
    
    while [[ ${elapsed} -lt ${max_wait} ]]; do
        local cert_status=$(get_certificate_status "${profile}" "${cert_arn}")
        
        case "${cert_status}" in
            "ISSUED")
                log_success "Certificate validation completed successfully"
                return 0
                ;;
            "PENDING_VALIDATION")
                log_info "Certificate validation in progress, waiting ${wait_interval} seconds..."
                ;;
            "FAILED")
                log_error "Certificate validation failed"
                return 1
                ;;
            *)
                log_warning "Unknown certificate status: ${cert_status}"
                ;;
        esac
        
        sleep ${wait_interval}
        elapsed=$((elapsed + wait_interval))
    done
    
    log_error "Certificate validation timeout reached"
    return 1
}

# Tag certificate with mandatory tags
tag_certificate() {
    local profile="$1"
    local cert_arn="$2"
    
    log_info "Tagging certificate: ${cert_arn}"
    
    # Create tags
    local tag_result=$(aws acm add-tags-to-certificate \
        --certificate-arn "${cert_arn}" \
        --tags "Key=Project,Value=${PROJECT_PREFIX}" "Key=Environment,Value=${ENVIRONMENT}" \
        --profile "${profile}" 2>&1)
    
    if [[ $? -eq 0 ]]; then
        log_success "Certificate tagged successfully"
        return 0
    else
        log_error "Failed to tag certificate"
        log_error "Error: ${tag_result}"
        return 1
    fi
}

# Main function to manage SSL certificates
manage_ssl_certificates() {
    log_info "Managing SSL certificates"
    
    local domain=$(echo "${CONFIG_DATA}" | jq -r '.domain')
    if [[ -z "${domain}" || "${domain}" == "null" ]]; then
        log_error "Domain not found in configuration"
        return 1
    fi
    
    log_info "Managing SSL certificate for domain: ${domain}"
    CERTIFICATE_DOMAIN="${domain}"
    
    # Try to find existing certificate first
    local search_output=$(search_existing_certificates "${HOSTING_PROFILE}" "${domain}" 2>&1)
    local search_status=$?
    local existing_cert_arn=$(echo "${search_output}" | tail -n 1)
    
    # If search returned nothing, existing_cert_arn will be empty
    if [[ ${search_status} -eq 0 && -n "${existing_cert_arn}" && "${existing_cert_arn}" != "" ]]; then
        log_info "Found existing certificate, validating status"
        
        local cert_status=$(get_certificate_status "${HOSTING_PROFILE}" "${existing_cert_arn}")
        local status_status=$?
        
        if [[ ${status_status} -eq 0 ]]; then
            case "${cert_status}" in
                "ISSUED")
                    log_success "Existing certificate is already validated and issued"
                    CERTIFICATE_ARN="${existing_cert_arn}"
                    CERTIFICATE_VALIDATION_COMPLETE="true"
                    ;;
                "PENDING_VALIDATION")
                    log_info "Found existing certificate pending validation, will complete validation"
                    CERTIFICATE_ARN="${existing_cert_arn}"
                    # Don't reset existing_cert_arn, we'll use this certificate
                    ;;
                *)
                    log_warning "Existing certificate status is: ${cert_status}"
                    log_info "Will create new certificate"
                    existing_cert_arn=""
                    ;;
            esac
        else
            log_warning "Failed to get certificate status, will create new certificate"
            existing_cert_arn=""
        fi
    else
        existing_cert_arn=""
    fi
    
    # If certificate validation is already complete, skip to the end
    if [[ "${CERTIFICATE_VALIDATION_COMPLETE}" == "true" ]]; then
        log_success "Using existing validated certificate"
    else
        # We need to complete validation (either for existing or new certificate)
        if [[ -z "${existing_cert_arn}" ]]; then
            # No existing certificate, create new one
            log_info "Creating new SSL certificate"
            
            # Request new certificate
            local cert_request_output=$(request_ssl_certificate "${HOSTING_PROFILE}" "${domain}" 2>&1)
            local cert_request_status=$?
            local new_cert_arn=$(echo "${cert_request_output}" | tail -n 1)
            
            if [[ ${cert_request_status} -ne 0 ]]; then
                log_error "Failed to request SSL certificate"
                return 1
            fi
            
            CERTIFICATE_ARN="${new_cert_arn}"
        else
            # Use existing certificate that needs validation
            log_info "Completing validation for existing certificate"
        fi
        
        # Get DNS validation records (works for both new and existing certificates)
        local validation_records=$(get_dns_validation_records "${HOSTING_PROFILE}" "${CERTIFICATE_ARN}")
        local validation_status=$?
        
        if [[ ${validation_status} -ne 0 ]]; then
            log_error "Failed to get DNS validation records"
            return 1
        fi
        
        # Get hosted zone ID
        local hosted_zone_id=$(get_hosted_zone_id "${INFRASTRUCTURE_PROFILE}" "${domain}")
        local zone_status=$?
        
        if [[ ${zone_status} -ne 0 ]]; then
            log_error "Failed to get hosted zone ID"
            return 1
        fi
        
        # Create DNS validation record
        local change_id=$(create_dns_validation_record "${INFRASTRUCTURE_PROFILE}" "${hosted_zone_id}" "${validation_records}")
        local change_status=$?
        
        if [[ ${change_status} -ne 0 ]]; then
            log_error "Failed to create DNS validation record"
            return 1
        fi
        
        # Wait for DNS change to propagate
        wait_for_dns_change "${INFRASTRUCTURE_PROFILE}" "${change_id}"
        
        # Wait for certificate validation
        wait_for_certificate_validation "${HOSTING_PROFILE}" "${CERTIFICATE_ARN}"
        if [[ $? -ne 0 ]]; then
            log_error "Certificate validation failed or timed out"
            return 1
        fi
        
        CERTIFICATE_VALIDATION_COMPLETE="true"
    fi
    
    # Tag the certificate
    tag_certificate "${HOSTING_PROFILE}" "${CERTIFICATE_ARN}"
    
    # Export variables for use in other functions
    export CERTIFICATE_ARN
    export CERTIFICATE_DOMAIN
    export CERTIFICATE_VALIDATION_COMPLETE
    
    log_success "SSL certificate management completed successfully"
    log_info "Certificate ARN: ${CERTIFICATE_ARN}"
}

# Function to clean up certificate resources during destruction
cleanup_certificate_resources() {
    log_info "Cleaning up certificate resources"
    
    local domain=$(echo "${CONFIG_DATA}" | jq -r '.domain')
    if [[ -z "${domain}" || "${domain}" == "null" ]]; then
        log_warning "Domain not found in configuration, skipping certificate cleanup"
        return 0
    fi
    
    # Find certificate for domain (capture output without displaying search logs)
    local search_output=$(search_existing_certificates "${HOSTING_PROFILE}" "${domain}" 2>&1)
    local search_status=$?
    local cert_arn=$(echo "${search_output}" | tail -n 1)
    
    # Only consider it found if the search was successful and returned a non-empty ARN
    if [[ ${search_status} -eq 0 && -n "${cert_arn}" && "${cert_arn}" =~ ^arn:aws:acm: ]]; then
        log_warning "Found certificate for domain: ${domain}"
        log_warning "Certificate ARN: ${cert_arn}"
        log_warning "Note: Certificates are not automatically deleted for safety"
        log_warning "If you need to delete the certificate, do so manually from the AWS Console"
        log_warning "This preserves certificates that might be used by other resources"
    else
        log_info "No certificates found for domain: ${domain}"
    fi
    
    log_success "Certificate resource cleanup completed"
}

# Export functions for use in main scripts
export -f search_existing_certificates get_certificate_status validate_exact_domain_match
export -f request_ssl_certificate get_dns_validation_records get_hosted_zone_id
export -f create_dns_validation_record wait_for_dns_change wait_for_certificate_validation
export -f tag_certificate manage_ssl_certificates cleanup_certificate_resources