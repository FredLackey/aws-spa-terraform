#!/bin/bash

# Stage 02 Infrastructure Setup - Validation Script
# End-to-end testing using curl and connectivity checks

set -euo pipefail

# Script directory and imports
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

# Test result tracking
TESTS_PASSED=0
TESTS_FAILED=0
VALIDATION_ERRORS=()

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to run a test
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_pattern="$3"
    
    echo -n "Testing $test_name... "
    
    if result=$(eval "$test_command" 2>&1); then
        if [[ "$result" =~ $expected_pattern ]]; then
            echo -e "${GREEN}✅ PASS${NC}"
            ((TESTS_PASSED++))
            return 0
        else
            echo -e "${RED}❌ FAIL${NC} (Unexpected response)"
            echo "  Expected pattern: $expected_pattern"
            echo "  Got: $result"
            VALIDATION_ERRORS+=("$test_name: Unexpected response pattern")
            ((TESTS_FAILED++))
            return 1
        fi
    else
        echo -e "${RED}❌ FAIL${NC} (Command failed)"
        echo "  Error: $result"
        VALIDATION_ERRORS+=("$test_name: Command execution failed")
        ((TESTS_FAILED++))
        return 1
    fi
}

# Function to test HTTP endpoint
test_http_endpoint() {
    local url="$1"
    local description="$2"
    local expected_status="$3"
    local expected_content="$4"
    
    echo -n "Testing $description... "
    
    # Make HTTP request with timeout
    if response=$(curl -s -w "HTTPSTATUS:%{http_code}" --max-time 30 "$url" 2>&1); then
        # Extract HTTP status and body
        http_body=$(echo "$response" | sed -E 's/HTTPSTATUS:[0-9]{3}$//')
        http_status=$(echo "$response" | tr -d '\n' | sed -E 's/.*HTTPSTATUS:([0-9]{3})$/\1/')
        
        # Check status code
        if [[ "$http_status" -eq "$expected_status" ]]; then
            # Check content if provided
            if [[ -n "$expected_content" ]] && [[ ! "$http_body" =~ $expected_content ]]; then
                echo -e "${RED}❌ FAIL${NC} (Unexpected content)"
                echo "  Expected content: $expected_content"
                echo "  Response body: $http_body"
                VALIDATION_ERRORS+=("$description: Content validation failed")
                ((TESTS_FAILED++))
                return 1
            else
                echo -e "${GREEN}✅ PASS${NC}"
                ((TESTS_PASSED++))
                return 0
            fi
        else
            echo -e "${RED}❌ FAIL${NC} (HTTP $http_status)"
            echo "  Expected: HTTP $expected_status"
            echo "  Response body: $http_body"
            VALIDATION_ERRORS+=("$description: HTTP status $http_status instead of $expected_status")
            ((TESTS_FAILED++))
            return 1
        fi
    else
        echo -e "${RED}❌ FAIL${NC} (Connection failed)"
        echo "  Error: $response"
        VALIDATION_ERRORS+=("$description: Connection failed")
        ((TESTS_FAILED++))
        return 1
    fi
}

echo "=== Stage 02 Infrastructure Validation ==="
echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo

# Load configuration
load_configuration

# Get URLs from Terraform outputs
if [[ -f "../terraform.tfstate" ]] || terraform state list >/dev/null 2>&1; then
    APP_URL=$(terraform -chdir=".." output -raw application_url 2>/dev/null || echo "")
    API_BASE_URL=$(terraform -chdir=".." output -raw api_base_url 2>/dev/null || echo "")
    CLOUDFRONT_DISTRIBUTION_ID=$(terraform -chdir=".." output -raw cloudfront_distribution_id 2>/dev/null || echo "")
    LAMBDA_FUNCTION_NAME=$(terraform -chdir=".." output -raw lambda_function_name 2>/dev/null || echo "")
    S3_BUCKET_NAME=$(terraform -chdir=".." output -raw s3_bucket_name 2>/dev/null || echo "")
else
    echo -e "${YELLOW}⚠️  Warning: No Terraform state found. Using configuration values.${NC}"
    APP_URL="https://$DOMAIN"
    API_BASE_URL="https://$DOMAIN/api"
    CLOUDFRONT_DISTRIBUTION_ID=""
    LAMBDA_FUNCTION_NAME=""
    S3_BUCKET_NAME=""
fi

echo "=== Configuration ==="
echo "Application URL: $APP_URL"
echo "API Base URL: $API_BASE_URL"
echo "CloudFront Distribution ID: $CLOUDFRONT_DISTRIBUTION_ID"
echo "Lambda Function Name: $LAMBDA_FUNCTION_NAME"
echo "S3 Bucket Name: $S3_BUCKET_NAME"
echo

echo "=== Infrastructure Validation Tests ==="

# Test 1: React Application (HTML Response)
echo "--- React Application Tests ---"
test_http_endpoint "$APP_URL" "React application root" 200 "<!DOCTYPE html>"

# Test 2: API Health Check
echo
echo "--- API Endpoint Tests ---"
test_http_endpoint "$API_BASE_URL/" "API health check" 200 '"status":"healthy"'

# Test 3: API Echo Endpoint
test_http_endpoint "$API_BASE_URL/echo" "API echo endpoint" 200 '"message":"Echo response"'

# Test 4: CloudFront Behavior Routing
echo
echo "--- CloudFront Behavior Tests ---"
if [[ -n "$CLOUDFRONT_DISTRIBUTION_ID" ]]; then
    run_test "CloudFront distribution status" \
        "aws cloudfront get-distribution --id '$CLOUDFRONT_DISTRIBUTION_ID' --query 'Distribution.Status' --output text" \
        "Deployed"
else
    echo -e "${YELLOW}⚠️  Skipping CloudFront tests (no distribution ID)${NC}"
fi

# Test 5: DNS Resolution
echo
echo "--- DNS Resolution Tests ---"
run_test "DNS resolution for $DOMAIN" \
    "nslookup '$DOMAIN'" \
    "Non-authoritative answer"

# Test 6: SSL Certificate
echo
echo "--- SSL Certificate Tests ---"
run_test "SSL certificate validation" \
    "echo | openssl s_client -servername '$DOMAIN' -connect '$DOMAIN:443' 2>/dev/null | openssl x509 -noout -subject" \
    "CN.*$DOMAIN"

# Test 7: Lambda Function
echo
echo "--- Lambda Function Tests ---"
if [[ -n "$LAMBDA_FUNCTION_NAME" ]]; then
    run_test "Lambda function status" \
        "aws lambda get-function --function-name '$LAMBDA_FUNCTION_NAME' --query 'Configuration.State' --output text" \
        "Active"
else
    echo -e "${YELLOW}⚠️  Skipping Lambda tests (no function name)${NC}"
fi

# Test 8: S3 Bucket
echo
echo "--- S3 Bucket Tests ---"
if [[ -n "$S3_BUCKET_NAME" ]]; then
    run_test "S3 bucket accessibility" \
        "aws s3 ls 's3://$S3_BUCKET_NAME'" \
        ".*"
else
    echo -e "${YELLOW}⚠️  Skipping S3 tests (no bucket name)${NC}"
fi

# Test 9: Performance Test
echo
echo "--- Performance Tests ---"
test_response_time() {
    local url="$1"
    local max_time="$2"
    
    echo -n "Testing response time for $url (max ${max_time}s)... "
    
    if response_time=$(curl -w "%{time_total}" -o /dev/null -s --max-time "$max_time" "$url" 2>/dev/null); then
        # Convert to integer comparison (multiply by 1000 for milliseconds)
        if (( $(echo "$response_time < $max_time" | bc -l) )); then
            echo -e "${GREEN}✅ PASS${NC} (${response_time}s)"
            ((TESTS_PASSED++))
        else
            echo -e "${RED}❌ FAIL${NC} (${response_time}s > ${max_time}s)"
            VALIDATION_ERRORS+=("Response time test: ${response_time}s exceeds ${max_time}s")
            ((TESTS_FAILED++))
        fi
    else
        echo -e "${RED}❌ FAIL${NC} (Request timeout or failed)"
        VALIDATION_ERRORS+=("Response time test: Request failed")
        ((TESTS_FAILED++))
    fi
}

test_response_time "$APP_URL" 10
test_response_time "$API_BASE_URL/" 5

echo
echo "=== Validation Summary ==="
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
echo "Total Tests: $((TESTS_PASSED + TESTS_FAILED))"

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo
    echo -e "${GREEN}🎉 All validation tests passed!${NC}"
    echo
    echo "=== Manual Testing Recommendations ==="
    echo "1. Open the application in your browser: $APP_URL"
    echo "2. Test the API using the React application's test button"
    echo "3. Verify CloudFront caching behavior"
    echo "4. Check CloudWatch logs for Lambda execution"
    echo "5. Monitor performance and error rates"
    
    exit 0
else
    echo
    echo -e "${RED}❌ Some validation tests failed!${NC}"
    echo
    echo "Errors encountered:"
    for error in "${VALIDATION_ERRORS[@]}"; do
        echo -e "  ${RED}•${NC} $error"
    done
    echo
    echo "=== Troubleshooting Steps ==="
    echo "1. Check CloudFront distribution deployment status"
    echo "2. Verify DNS propagation (may take time)"
    echo "3. Review Terraform outputs and AWS console"
    echo "4. Check CloudWatch logs for errors"
    echo "5. Ensure SSL certificate is valid and associated"
    
    exit 1
fi