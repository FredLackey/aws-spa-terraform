# Stage 02: Infrastructure Setup Requirements

## Overview

Stage 02: Infrastructure Setup (02-infra-setup) is responsible for creating the core application infrastructure components including CloudFront CDN, Lambda functions, and S3 storage using AWS CLI and Bash scripting. This stage builds upon the foundational resources established in Stage 01 and prepares the environment for application deployment in subsequent stages.

## Stage Purpose

This stage provisions the AWS serverless infrastructure required to host a Single Page Application (SPA) with the following architecture:
- **CloudFront Distribution**: Global CDN for content delivery with custom domain and SSL
- **S3 Bucket**: Static website hosting for React frontend assets  
- **Lambda Function**: Serverless backend API execution
- **Route Configuration**: CloudFront behaviors routing `/` to S3 and `/api/*` to Lambda

## Implementation Approach

**Tooling**: Pure AWS CLI and Bash scripting (no Terraform)
**State Management**: JSON configuration files for resource tracking
**Pattern**: Discovery-first approach with idempotent operations
**Integration**: Follows established data flow patterns from Stages 00-01

## Input Requirements

### Automatic Input Discovery
The stage automatically copies the previous stage's output configuration:
- **Source**: `../01-infra-foundation/output/{project-prefix}-config-{environment}.json`
- **Destination**: `input/{project-prefix}-config-{environment}.json`

### Required Input Data (from Stage 01)
- **Project Configuration**: project_prefix, environment, region, domain
- **AWS Account Information**: infrastructure_account_id, hosting_account_id
- **Network Configuration**: vpc_id
- **Security Resources**: certificate_arn, cross_account_role_arn
- **DNS Configuration**: hosted_zone_id

### Optional Parameters
- `--cdn-price-class`: CloudFront price class (default: PriceClass_100)
- `--lambda-memory`: Lambda memory allocation in MB (default: 128)
- `--input-file`: Override automatic input discovery with custom file path
- `--help`: Display usage information

## AWS Resources Created

### 1. S3 Bucket for Static Hosting
**Purpose**: Host compiled React application assets
**Configuration**:
- Bucket name: `{project-prefix}-webapp-{environment}-{timestamp}` (YYYYMMDDHHMMSS format)
- Static website hosting enabled
- Public read access for website content
- Bucket policy allowing CloudFront access
- Standard resource tags (Project, Environment)

### 2. Lambda Function for API Backend
**Purpose**: Execute placeholder API backend code
**Configuration**:
- Function name: `{project-prefix}-api-{environment}`
- Runtime: Node.js >= 20.0 (project minimum requirement)
- Memory: Configurable via `--lambda-memory` parameter (default: 128MB)
- Timeout: 30 seconds
- Environment variables: Configuration data as needed
- IAM execution role: Basic Lambda execution permissions
- Standard resource tags (Project, Environment)

### 3. CloudFront Distribution
**Purpose**: Global CDN with custom domain and routing behaviors
**Configuration**:
- Custom domain: From input configuration
- SSL certificate: Using certificate_arn from Stage 01
- Price class: Configurable via `--cdn-price-class` parameter
- Behaviors:
  - `/` → S3 bucket (default behavior for React app)
  - `/api/*` → Lambda function (API routes)
- Caching policies: Optimized for SPA and API patterns
- Standard resource tags (Project, Environment)

## Application Deployment

### Placeholder React Application
**Source**: `packages/placeholder-react-app/` (relative to project root)
**Important**: Application code already exists and must NOT be modified in any way
**Process**:
1. Navigate to existing placeholder React app directory
2. Install dependencies using npm (no package.json modifications)
3. Execute existing build process (`npm run build`)
4. Upload build artifacts to S3 bucket
5. Configure appropriate file permissions and content types

### Placeholder API Application  
**Source**: `packages/placeholder-api/` (relative to project root)
**Important**: Application code already exists and must NOT be modified in any way
**Process**:
1. Navigate to existing placeholder API directory
2. Install dependencies using npm (no package.json modifications)
3. Create deployment package (zip file) from existing code
4. Deploy package to Lambda function
5. Update function configuration as needed

## Discovery and Idempotency Logic

**CRITICAL**: All operations must be fully idempotent to support repeated deploy/destroy cycles. Scripts check if each step is required before executing it.

### S3 Bucket Discovery
- Generate timestamp suffix (YYYYMMDDHHMMSS) for new bucket naming
- Check if any bucket with project prefix exists using AWS CLI list operations
- Create new timestamped bucket for fresh content delivery
- Configure bucket for static website hosting, policies, and public access
- Update CloudFront origin to point to new bucket when bucket is recreated

### Lambda Function Discovery
- Check if function with expected name exists using AWS CLI describe operations
- Compare current configuration (memory, timeout, runtime, environment variables)
- Update function configuration if changes detected vs. required state
- Create function if not found
- Update function code if application changes detected (compare checksums)

### CloudFront Distribution Discovery
- Check if distribution with custom domain exists using AWS CLI list operations
- Validate current configuration (behaviors, SSL, price class, origins)
- Update distribution if changes detected vs. required state
- Create distribution if not found
- Wait for distribution deployment completion with timeout handling

### State Consistency Requirements
- Scripts check if each step is required before executing it
- All operations must provide clear logging of discovered vs. desired state
- Scripts can be run multiple times without negative impact from previous runs

## Validation Requirements

### Infrastructure Validation
1. **S3 Bucket Verification**
   - Confirm bucket exists and is accessible
   - Verify website hosting configuration
   - Test object upload and retrieval

2. **Lambda Function Verification**
   - Confirm function exists and is active
   - Test function invocation with sample payload
   - Verify function configuration matches requirements

3. **CloudFront Distribution Verification**
   - Confirm distribution is deployed and active
   - Verify SSL certificate is properly configured
   - Test custom domain resolution

### Application Validation
1. **Frontend Application Testing**
   - Use curl to test CloudFront root URL (`/`)
   - Verify React application renders successfully
   - Confirm appropriate HTTP response codes and headers

### End-to-End Validation
- Confirm SSL/TLS functionality on custom domain
- Verify application accessibility via CloudFront

## Output Configuration

### Enhanced Configuration Data
The stage enhances the input configuration by adding infrastructure resources to the existing configuration structure:
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

### Output File Location
**Destination**: `output/{project-prefix}-config-{environment}.json`
**Content**: Enhanced configuration with all previous stage data plus Stage 02 infrastructure resources
**Format**: JSON with proper formatting and validation

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

## Script Functionality

### deploy.sh Workflow
1. **Authentication Validation**: Verify AWS SSO login and permissions
2. **Input Processing**: Load and validate configuration from previous stage
3. **Parameter Processing**: Handle optional command-line parameters
4. **Resource Discovery**: Check existing infrastructure state
5. **Application Building**: Compile React and package API applications
6. **Infrastructure Deployment**: Create/update AWS resources as needed
7. **Application Deployment**: Deploy applications to infrastructure
8. **Validation Testing**: Comprehensive end-to-end testing
9. **Output Generation**: Create enhanced configuration for next stage

### destroy.sh Workflow
1. **Authentication Validation**: Verify AWS SSO login and permissions
2. **Resource Discovery**: Identify resources created by this stage
3. **Dependency Handling**: Remove resources in correct order
4. **S3 Cleanup**: Empty bucket contents before deletion
5. **CloudFront Cleanup**: Disable and delete distribution
6. **Lambda Cleanup**: Remove function and associated resources
7. **Validation**: Confirm complete resource removal

## Error Handling and Recovery

### Common Error Scenarios
- **AWS Authentication Failures**: Clear error messages with SSO login instructions
- **Resource Creation Conflicts**: Handle existing resources gracefully with state detection
- **Application Build Failures**: Detailed error reporting for npm/build issues with retry capability
- **CloudFront Propagation Delays**: Appropriate wait conditions and timeouts with progress reporting
- **Network Connectivity Issues**: Retry logic for transient failures with exponential backoff
- **Resource Deletion Dependencies**: Handle deletion order and dependency cleanup in destroy.sh

### Recovery Strategies
- **Partial Deployment Failures**: Re-run deploy.sh safely after corrections - must continue from failure point
- **Resource State Inconsistencies**: Discovery logic handles mixed states and corrects configuration drift
- **Application Deployment Issues**: Independent retry of application deployment steps without affecting infrastructure
- **Validation Failures**: Clear reporting of specific validation issues with suggested remediation
- **Interrupted Executions**: Scripts must detect incomplete operations and resume appropriately

### Script Execution Requirements
During development and testing phase:

1. **Idempotent Execution**
   - Scripts check if each step is required before executing
   - Scripts can be run multiple times without negative impact
   - Failed executions can be resolved by fixing issues and re-running scripts

2. **Bidirectional Testing**
   - `./deploy.sh` followed by `./destroy.sh` must execute without errors
   - `./destroy.sh` followed by `./deploy.sh` must execute without errors  
   - This cycle can be repeated indefinitely without failures
   - **Development is not complete until this requirement is satisfied**

## Success Criteria

### Deployment Success Indicators
- All AWS resources created successfully with proper configuration
- Placeholder applications compiled and deployed without errors
- All validation checks pass (infrastructure and application)
- Enhanced configuration file created with complete resource information
- CloudFront distribution serving content on custom domain with SSL

### Operational Success Indicators
- deploy.sh can be executed multiple times without errors
- destroy.sh completely removes all created resources
- Stage transitions smoothly to Stage 03 with proper output configuration
- All operations complete within reasonable time limits (< 20 minutes)
- Comprehensive logging provides clear audit trail of all operations



## Dependencies

### External Dependencies
- AWS CLI v2 properly configured
- Node.js >= 20.0 (project minimum requirement) for application building
- npm package manager
- jq for JSON processing
- Standard bash utilities (curl, zip, etc.)

### Stage Dependencies
- **Stage 00**: Project configuration and discovery data
- **Stage 01**: SSL certificates, IAM roles, and foundational resources
- **Placeholder Applications**: Existing React and API code in `/packages/` directories (must not be modified)

### AWS Permissions Required
- S3: Bucket creation, configuration, and object management
- Lambda: Function creation, configuration, and deployment
- CloudFront: Distribution creation, configuration, and management
- IAM: Role assumption for cross-account access (using Stage 01 roles)