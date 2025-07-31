# Product Requirements Document: Stage 02 Infrastructure Setup

## Introduction/Overview

Stage 02: Infrastructure Setup creates the core application infrastructure components required to host a Single Page Application (SPA) using AWS serverless services. This stage uses AWS CLI and bash scripting to provision CloudFront CDN, Lambda functions, and S3 storage, following the same patterns established in Stages 00 and 01. The stage must be fully idempotent, allowing unlimited deploy/destroy cycles without manual intervention.

**Problem Solved**: Provides the AWS infrastructure foundation needed to host a React frontend and Node.js API backend using serverless architecture with global CDN distribution and custom domain SSL.

## Goals

1. Create S3 bucket for static website hosting of React frontend assets
2. Deploy Lambda function for serverless API backend execution
3. Configure CloudFront distribution with custom domain and SSL certificate
4. Establish routing behaviors: `/` → S3 bucket, `/api/*` → Lambda function
5. Deploy placeholder React and API applications to the infrastructure
6. Maintain complete idempotency for deploy/destroy script operations
7. Preserve all configuration data from Stage 01 while adding Stage 02 resources
8. Enable seamless transition to Stage 03 with enhanced configuration output

## User Stories

### As a DevOps Engineer
- I want to run `./deploy.sh` and have all infrastructure provisioned automatically so that I don't need to manually configure AWS resources
- I want to run `./deploy.sh` multiple times without errors so that I can recover from failures by simply re-running the script
- I want to run `./destroy.sh` to completely remove all Stage 02 resources so that I can clean up environments when needed
- I want the stage to automatically discover input from Stage 01 so that I don't need to manually specify configuration files

### As a Developer
- I want existing placeholder applications automatically built and deployed without modification so that I can immediately test the infrastructure
- I want CloudWatch logging enabled for API errors so that I can troubleshoot backend issues
- I want wildcard CORS access from CloudFront so that I can develop and test from any domain

### As a System Administrator
- I want deliberate, predictable resource naming without random suffixes so that I can easily identify and manage resources
- I want the stage to detect existing resources and only create what's missing so that partial deployments can be recovered
- I want comprehensive logging of all operations so that I can audit and troubleshoot deployments

## Functional Requirements

### Core Infrastructure Requirements

1. **S3 Bucket Creation**
   - The system must create an S3 bucket named `{project-prefix}-webapp-{environment}-{timestamp}` using YYYYMMDDHHMMSS format
   - The system must enable static website hosting on the S3 bucket
   - The system must configure public read access for website content
   - The system must apply bucket policy allowing CloudFront access
   - The system must tag the bucket with Project and Environment tags

2. **Lambda Function Deployment**
   - The system must create a Lambda function named `{project-prefix}-api-{environment}`
   - The system must use Node.js 20.x runtime (minimum project requirement)
   - The system must set configurable memory allocation (default: 128MB, range: 128-10240MB)
   - The system must set function timeout to 30 seconds
   - The system must create basic execution role with Lambda permissions
   - The system must enable CloudWatch logging for API errors
   - The system must tag the function with Project and Environment tags

3. **CloudFront Distribution Configuration**
   - The system must create CloudFront distribution with custom domain from Stage 01
   - The system must configure SSL certificate using certificate_arn from Stage 01
   - The system must set configurable price class (default: PriceClass_100)
   - The system must create behavior routing `/` to S3 bucket (default behavior)
   - The system must create behavior routing `/api/*` to Lambda function
   - The system must allow wildcard access from any origin
   - The system must tag the distribution with Project and Environment tags

### Application Deployment Requirements

4. **React Application Deployment**
   - The system must navigate to existing `packages/placeholder-react-app/` directory
   - The system must NOT modify any application code, UI, or configuration files
   - The system must run `npm install` to install dependencies (no package.json changes)
   - The system must run `npm run build` to compile the existing application
   - The system must upload build artifacts to the S3 bucket
   - The system must set appropriate content types for web assets

5. **API Application Deployment**
   - The system must navigate to existing `packages/placeholder-api/` directory
   - The system must NOT modify any application code, handlers, or configuration files
   - The system must run `npm install` to install dependencies (no package.json changes)
   - The system must create deployment package (zip file) from existing code
   - The system must deploy package to Lambda function
   - The system must update function configuration as needed

### Idempotency and Discovery Requirements

6. **Resource Discovery Logic**
   - The system must check if each step is required before executing it
   - The system must generate timestamp suffix (YYYYMMDDHHMMSS) for S3 bucket naming
   - The system must create new timestamped S3 bucket for fresh content delivery
   - The system must update CloudFront origin to point to new bucket when recreated
   - The system must check if Lambda function exists before attempting creation
   - The system must validate existing function configuration against requirements
   - The system must check if CloudFront distribution exists before attempting creation
   - The system must validate existing distribution configuration against requirements

7. **Configuration Management**
   - The system must automatically discover input from `../01-infra-foundation/output/{project-prefix}-config-{environment}.json`
   - The system must copy input configuration to `input/{project-prefix}-config-{environment}.json`
   - The system must preserve all Stage 01 configuration data in output
   - The system must add Stage 02 resource information to output configuration

### Script Operation Requirements

8. **Deploy Script Functionality**
   - The system must accept optional `--cdn-price-class` parameter (PriceClass_100, PriceClass_200, PriceClass_All)
   - The system must accept optional `--lambda-memory` parameter (128-10240 MB)
   - The system must accept optional `--input-file` parameter for custom input path
   - The system must accept `--help` parameter to display usage information
   - The system must validate AWS CLI authentication before proceeding
   - The system must create comprehensive logs in `logs/` directory
   - The system must implement wait loops with continuous checking for resources with deployment delays (CloudFront distributions, etc.)
   - The system must not proceed to the next step until the current step is validated as successful and complete

9. **Destroy Script Functionality**
   - The system must identify all resources created by this stage
   - The system must empty S3 bucket contents before deletion
   - The system must remove all timestamped S3 buckets for the project/environment
   - The system must disable CloudFront distribution before deletion
   - The system must remove resources in correct dependency order
   - The system must verify complete resource removal after deletion

### Validation Requirements

10. **Infrastructure Validation**
    - The system must verify S3 bucket exists and is accessible
    - The system must verify Lambda function exists and is active
    - The system must verify CloudFront distribution is deployed and active
    - The system must verify SSL certificate is properly configured
    - The system must use curl testing within deploy.sh script to validate CloudFront distribution rendering
    - Every deployment step must be checked and validated immediately after completion using appropriate validation techniques
    - The system must perform end-to-end curl testing to verify complete request flow through CloudFront to both S3 and Lambda origins

11. **Operational Validation**
    - The system must allow `./deploy.sh` to run successfully multiple times without negative impact
    - The system must allow `./destroy.sh` to run successfully multiple times without negative impact
    - The system must allow `./deploy.sh` followed by `./destroy.sh` cycle repeatedly
    - Scripts check if each step is required before executing it to ensure idempotency
    - The deploy.sh script must validate each step immediately after execution before proceeding to the next step
    - All validation must use appropriate testing methods including curl for web accessibility testing

## Non-Goals (Out of Scope)

1. **Performance Optimization**: No specific performance benchmarks or optimization requirements
2. **Cost Optimization**: No cost constraints beyond configurable parameters
3. **Advanced Security**: No VPC endpoints, security groups, or encryption beyond SSL
4. **Monitoring Beyond Errors**: No comprehensive CloudWatch metrics or alarms
5. **Load Testing**: No performance or load testing capabilities
6. **Advanced Error Recovery**: No automatic retry mechanisms or exponential backoff
7. **Environment Differentiation**: No special behavior for different environments
8. **Random Resource Naming**: All resources use deliberate, predictable naming patterns
9. **Data Migration**: No data preservation or migration from previous deployments
10. **Manual Intervention**: No operations requiring human input during execution
11. **Application Modification**: No changes to existing placeholder application code, UI, handlers, or configurations

## Technical Considerations

### Implementation Approach
- **Tooling**: Pure AWS CLI and Bash scripting (no Terraform)
- **State Management**: JSON configuration files for resource tracking
- **Pattern**: Discovery-first approach with idempotent operations
- **Integration**: Follows established data flow patterns from Stages 00-01

### Dependencies
- AWS CLI v2 properly configured and authenticated
- Node.js >= 20.0 for application building
- npm package manager for dependency management
- jq for JSON processing
- Standard bash utilities (curl, zip, etc.)
- Successful completion of Stage 00 (Discovery) and Stage 01 (Infrastructure Foundation)
- Existing placeholder applications in `/packages/` directories (must not be modified)

### Resource Naming Convention
- S3 Bucket: `{project-prefix}-webapp-{environment}-{timestamp}` (YYYYMMDDHHMMSS format)
- Lambda Function: `{project-prefix}-api-{environment}`
- CloudFront Distribution: Uses custom domain from configuration
- Timestamp ensures fresh content delivery through CloudFront

## Success Metrics

### Primary Success Criteria
1. **Deploy Success Rate**: `./deploy.sh` executes successfully from clean state (100% requirement)
2. **Destroy Success Rate**: `./destroy.sh` executes successfully and removes all resources (100% requirement)
3. **Idempotency Success Rate**: Deploy/destroy cycle can be repeated indefinitely (100% requirement)
4. **Bidirectional Execution Rate**: `./deploy.sh` followed by `./destroy.sh` followed by `./deploy.sh` cycle can be repeated without errors (100% requirement)
5. **Development Completion Criteria**: Both scripts must run without error in sequence before development is considered complete (100% requirement)

### Secondary Success Indicators
1. **Application Accessibility**: Placeholder React application accessible via CloudFront domain
2. **SSL Functionality**: HTTPS access works correctly with custom domain  
3. **Static Content**: `/` requests route correctly to S3 bucket and React application renders
4. **Configuration Continuity**: Stage 03 can consume output configuration successfully

### Operational Metrics
1. **Execution Time**: Complete deployment finishes within 20 minutes
2. **Error Recovery**: Clear error messages guide users to resolution
3. **Log Quality**: Comprehensive audit trail of all operations
4. **Resource Cleanup**: No orphaned resources after destroy operation

## Directory Structure

```
iac/02-infra-setup/
├── deploy.sh                    # Main deployment entry point
├── destroy.sh                   # Main destruction entry point
├── scripts/                     # Modular bash functions
│   ├── s3-operations.sh         # S3 bucket management functions
│   ├── lambda-operations.sh     # Lambda function management functions
│   ├── cloudfront-operations.sh # CloudFront distribution management functions
│   ├── app-operations.sh        # Application build and deployment functions
│   ├── validation-functions.sh  # Resource validation functions
│   └── utils.sh                 # Common utilities and helper functions
├── config/                      # Stage-specific configuration templates
├── input/                       # Input configuration from Stage 01
├── output/                      # Enhanced configuration for Stage 03
├── logs/                        # Execution logs and audit trails
└── docs/                        # Stage documentation
    ├── README.md                # Stage-specific user documentation
    └── REQUIREMENTS.md          # Detailed requirements and specifications
```

## Enhanced Configuration Output

The stage creates an enhanced configuration file containing all Stage 01 data plus Stage 02 infrastructure resources:

```json
{
  "project": {
    "prefix": "myapp",
    "environment": "DEV", 
    "region": "us-east-1"
  },
  "aws": {
    "infrastructure_account_id": "111111111111",
    "hosting_account_id": "222222222222"
  },
  "domain": "myapp.dev.example.com",
  "vpc_id": "vpc-12345abcd",
  "certificate_arn": "arn:aws:acm:us-east-1:222222222222:certificate/12345678-1234-1234-1234-123456789012",
  "cross_account_role_arn": "arn:aws:iam::222222222222:role/myapp-dev-cross-account-role",
  "hosted_zone_id": "Z1234567890123",
  "s3_bucket_name": "{bucket-name}",
  "s3_bucket_arn": "{bucket-arn}",
  "s3_website_url": "{website-endpoint}",
  "lambda_function_name": "{function-name}",
  "lambda_function_arn": "{function-arn}",
  "cloudfront_distribution_id": "{distribution-id}",
  "cloudfront_distribution_arn": "{distribution-arn}",
  "cloudfront_domain_name": "{cloudfront-domain}",
  "application_url": "https://{custom-domain}"
}
```

## S3 Bucket Timestamp Logic

### Timestamp Generation
- **When Generated**: Timestamp (YYYYMMDDHHMMSS) is generated at the start of each deployment
- **Purpose**: Ensures CloudFront gets fresh content by creating new S3 bucket with unique name
- **Format**: Uses current UTC time in YYYYMMDDHHMMSS format (e.g., 20241210143022)

### Bucket Recreation Strategy
- **New Deployment**: Always creates new timestamped bucket for fresh content delivery
- **CloudFront Update**: Updates CloudFront origin to point to new timestamped bucket
- **Old Bucket Cleanup**: Once CloudFront is tested and validated to be serving the updated codebase correctly, the old timestamped bucket must be deleted to prevent resource accumulation
- **Idempotency**: Deploy script checks if current timestamped bucket exists before creation
- **Validation Before Cleanup**: Old bucket deletion only occurs after successful validation that CloudFront distribution is properly serving content from the new bucket

## CloudFront Propagation Handling Requirements

**CRITICAL REQUIREMENT**: The system must implement robust wait loops with continuous status checking for all resources that have deployment delays, particularly CloudFront distributions.

**Implementation Requirements**:
- **Wait Loop Implementation**: Deploy scripts must implement polling loops that continuously check resource status
- **Progress Indicators**: Scripts must provide clear progress indicators during wait periods
- **Timeout Limits**: Maximum wait time of 25 minutes for CloudFront distribution deployment
- **Status Validation**: Each iteration must validate actual resource status, not just wait arbitrary time periods
- **Error Detection**: Loops must detect and report deployment failures, not just timeouts
- **Next Step Blocking**: Scripts must not proceed to subsequent steps until current step validation confirms success

## Open Questions

1. **Application Build Failure Recovery**: If npm build fails during deployment, should the script continue with infrastructure provisioning or halt completely?

2. **Cross-Account Role Verification**: Should the stage verify cross-account role permissions before attempting resource creation, or rely on AWS API error handling?

3. **Configuration Drift Detection**: How detailed should the configuration comparison be when detecting existing resources that need updates?

4. **Log Retention**: How long should logs be retained in the `logs/` directory, and should there be automatic cleanup?

5. **AWS CLI Version Compatibility**: Should the scripts verify specific AWS CLI v2 minimum versions for feature compatibility?

6. **Network Timeout Handling**: What timeout values should be used for AWS CLI operations, and should there be different timeouts for different resource types?