# Task List: Stage 02 Infrastructure Setup

Based on PRD: Stage 02 Infrastructure Setup

## Relevant Files

- `iac/02-infra-setup/deploy.sh` - Main deployment script with command-line parameter handling and validation logic.
- `iac/02-infra-setup/destroy.sh` - Cleanup script for infrastructure teardown.
- `iac/02-infra-setup/docs/README.md` - Comprehensive documentation covering overview, usage, architecture, and troubleshooting.
- `iac/02-infra-setup/main.tf` - Root Terraform configuration defining providers and modules.
- `iac/02-infra-setup/variables.tf` - Variable definitions for configurable parameters (memory, timeout).
- `iac/02-infra-setup/outputs.tf` - Output definitions for Stage 03 consumption.
- `iac/02-infra-setup/backend.tf` - Terraform backend configuration for S3 + DynamoDB state management.
- `iac/02-infra-setup/modules/cloudfront/main.tf` - CloudFront distribution with behaviors and OAC configuration.
- `iac/02-infra-setup/modules/lambda/main.tf` - Lambda function configuration with Function URLs.
- `iac/02-infra-setup/modules/s3/main.tf` - S3 bucket configuration with CloudFront integration.
- `iac/02-infra-setup/modules/route53/main.tf` - DNS record management for custom domain.
- `iac/02-infra-setup/scripts/utils.sh` - Utility functions for configuration processing and validation.
- `iac/02-infra-setup/scripts/validation.sh` - End-to-end validation tests using curl and connectivity checks.

### Notes

- This stage follows the progressive configuration enhancement pattern: automatically discovers and copies Stage 01 output to current stage input directory
- Stage can run without parameters (using defaults) or with optional parameters for Lambda memory/timeout customization
- All Terraform modules should include proper resource tagging and dependency management
- Lambda Function URLs are used instead of API Gateway for direct CloudFront integration
- CloudFront Origin Access Control (OAC) is the modern approach for S3 access security
- React application build step ensures current version is deployed; manual API testing performed post-deployment

## Tasks

- [ ] 1.0 Set up Stage 02 Infrastructure Foundation
  - [ ] 1.1 Create directory structure for Stage 02 (`iac/02-infra-setup/` with subdirectories: `config/`, `input/`, `output/`, `logs/`, `scripts/`, `modules/`, `docs/`)
  - [ ] 1.2 Implement configuration file auto-discovery mechanism from Stage 01 output folder to Stage 02 input directory (environment and region automatically extracted from previous stage output)
  - [ ] 1.3 Create configuration parsing functions to extract certificate ARN, VPC ID, IAM role ARNs, and hosted zone information from Stage 01 output data
  - [ ] 1.4 Implement optional command-line parameter handling for `--memory/-m` (default 128MB) and `--timeout/-t` (default 15 seconds) - stage can run without parameters using defaults
  - [ ] 1.5 Add validation to ensure environment and region parameters are NOT accepted (automatically discovered from Stage 01 output configuration file per progressive enhancement pattern)
- [ ] 2.0 Configure Terraform Backend and State Management
  - [ ] 2.1 Create `backend.tf` with S3 backend configuration using naming convention `terraform-state-{project-prefix}-{environment}-infra`
  - [ ] 2.2 Configure DynamoDB table for state locking with naming convention `terraform-locks-{project-prefix}-{environment}-infra`
  - [ ] 2.3 Enable KMS encryption for Terraform state files
  - [ ] 2.4 Implement backend initialization with proper error handling and validation
- [ ] 3.0 Create CloudFront Distribution with Behavior Configuration
  - [ ] 3.1 Create CloudFront module with PriceClass_100 configuration
  - [ ] 3.2 Configure default behavior to serve React application from S3 origin with standard caching
  - [ ] 3.3 Configure `/api/*` behavior to forward requests to Lambda Function URL with no caching and all HTTP methods
  - [ ] 3.4 Implement Origin Access Control (OAC) for secure S3 access
  - [ ] 3.5 Associate SSL certificate ARN from Stage 01 input data
  - [ ] 3.6 Configure custom domain name using domain from project configuration
  - [ ] 3.7 Set up CORS configuration for React-to-API communication
- [ ] 4.0 Deploy Lambda Functions with Function URLs
  - [ ] 4.1 Create Lambda module with Node.js 20 runtime configuration
  - [ ] 4.2 Implement configurable memory allocation (using --memory parameter, default 128MB)
  - [ ] 4.3 Implement configurable timeout (using --timeout parameter, default 15 seconds)
  - [ ] 4.4 Deploy placeholder API code with health check endpoint at root path (`/`)
  - [ ] 4.5 Deploy placeholder API code with echo test endpoint (`/echo`)
  - [ ] 4.6 Configure Lambda Function URLs for direct CloudFront integration
  - [ ] 4.7 Associate IAM execution role from Stage 01 input data
  - [ ] 4.8 Configure VPC settings using Stage 01 VPC configuration
- [ ] 5.0 Configure S3 Bucket for Static Asset Hosting
  - [ ] 5.1 Create S3 module for static asset hosting bucket
  - [ ] 5.2 Configure bucket for CloudFront origin access without versioning
  - [ ] 5.3 Set up bucket policies to allow CloudFront distribution access only
  - [ ] 5.4 Block all public access and route everything through CloudFront
  - [ ] 5.5 Execute build step for placeholder React application to ensure current version is compiled and deploy assets to the bucket
- [ ] 6.0 Set up Route 53 DNS Configuration
  - [ ] 6.1 Create Route 53 module for DNS record management
  - [ ] 6.2 Create or update Route 53 A record to point custom domain to CloudFront distribution
  - [ ] 6.3 Use hosted zone ID from Stage 01 input data
  - [ ] 6.4 Configure alias record for optimal performance and cost
- [ ] 7.0 Implement Monitoring and Logging
  - [ ] 7.1 Enable CloudWatch logs for all Lambda functions with naming pattern `/aws/lambda/{project-prefix}-{environment}-{function-name}`
  - [ ] 7.2 Configure CloudFront error logging if lightweight options are available
  - [ ] 7.3 Use default CloudWatch log retention policies (no custom retention configuration needed)
  - [ ] 7.4 Apply standardized tags (`Project` and `Environment`) to all created resources
- [ ] 8.0 Create Deployment and Validation Scripts
  - [ ] 8.1 Create `deploy.sh` script with state-aware resource creation and existence checks
  - [ ] 8.2 Create `destroy.sh` script for infrastructure cleanup
  - [ ] 8.3 Implement utility functions in `scripts/utils.sh` for configuration processing
  - [ ] 8.4 Create validation script in `scripts/validation.sh` for end-to-end testing
  - [ ] 8.5 Implement curl test against custom domain to validate React application HTML response (primary validation method)
  - [ ] 8.6 Implement API connectivity validation using health check (`/`) and echo (`/echo`) endpoints via curl
  - [ ] 8.7 Validate CloudFront behaviors correctly route `/api/*` requests to Lambda functions
  - [ ] 8.8 Note: Manual API test via React application's test button should be performed after deployment completion
  - [ ] 8.9 Generate enhanced output configuration file combining Stage 01 data plus Stage 02 infrastructure details for Stage 03 consumption
  - [ ] 8.10 Create comprehensive documentation in `docs/README.md` covering overview, usage, architecture, and troubleshooting
- [ ] 9.0 Iterative Testing and Script Refinement
  - [ ] 9.1 Execute initial deployment test using `deploy.sh` with default parameters
  - [ ] 9.2 Validate all infrastructure components are created correctly and functional
  - [ ] 9.3 Execute destroy test using `destroy.sh` to ensure complete cleanup
  - [ ] 9.4 Verify all resources are properly removed (no orphaned resources)
  - [ ] 9.5 Re-deploy using `deploy.sh` to test repeatability and idempotency
  - [ ] 9.6 Test deployment with custom parameters (`--memory` and `--timeout`)
  - [ ] 9.7 Execute destroy and re-deploy cycle to validate parameter handling
  - [ ] 9.8 Fix any bugs discovered during deploy/destroy cycles
  - [ ] 9.9 Test edge cases: partial failures, network interruptions, state inconsistencies
  - [ ] 9.10 Perform final deploy/destroy/deploy cycle to confirm full reliability
  - [ ] 9.11 Document any known limitations or manual intervention requirements
  - [ ] 9.12 Validate that Stage 02 output configuration is properly generated for Stage 03 consumption