# Product Requirements Document: Stage 02 Infrastructure Setup

## Introduction/Overview

Stage 02 Infrastructure Setup is responsible for creating the core application infrastructure components using Terraform. This stage builds upon the foundational resources established in Stage 01 (certificate ARNs, IAM roles, hosted zones) to deploy the CloudFront distribution, Lambda functions, S3 buckets, and Route 53 DNS records needed to host the placeholder Single Page Application (SPA).

The primary goal is to establish a complete, functional web application infrastructure that serves the placeholder React frontend via CloudFront CDN and routes API requests to placeholder Lambda functions, demonstrating the full SPA deployment pattern before real applications are deployed in later stages.

## Goals

1. **Deploy Application Infrastructure**: Create CloudFront distribution, Lambda functions, and S3 buckets using Terraform
2. **Configure Domain Routing**: Set up Route 53 DNS records to point custom domains to the CloudFront distribution
3. **Enable API Communication**: Configure CloudFront behaviors to route `/api/*` requests to Lambda functions
4. **Deploy Placeholder Applications**: Install placeholder React app and placeholder API to validate infrastructure
5. **Implement Monitoring**: Set up basic CloudWatch logging for Lambda functions and CloudFront error logging
6. **Validate End-to-End Connectivity**: Ensure complete request flow from domain → CloudFront → React app and API endpoints

## User Stories

**As a DevOps Engineer**, I want to deploy application infrastructure using Terraform so that I can manage resources with Infrastructure as Code best practices.

**As a Developer**, I want the placeholder applications deployed so that I can validate the infrastructure works before deploying real business applications.

**As a Project Manager**, I want DNS records automatically configured so that stakeholders can access the application via the custom domain immediately after deployment.

**As a System Administrator**, I want basic monitoring in place so that I can detect and troubleshoot issues with the deployed infrastructure.

**As a DevOps Engineer**, I want each deployment step to validate current state so that scripts can be safely re-executed without causing conflicts.

## Functional Requirements

### 1. Input Data Processing
1.1. The system must automatically copy the output configuration file from Stage 01 to the current stage's input directory
1.2. The system must extract and validate all required configuration data including certificate ARN, VPC ID, IAM role ARNs, and hosted zone information
1.3. The system must accept optional command-line parameter for Lambda memory allocation (--memory/-m) with default 128MB to override Lambda default memory settings
1.4. The system must accept optional command-line parameter for Lambda timeout (--timeout/-t) with default 15 seconds to override Lambda default timeout for API requests
1.5. The system must NOT accept environment or region parameters, as these are automatically discovered from the Stage 01 output configuration file

### 2. Terraform Backend Configuration
2.1. The system must configure Terraform backend using S3 + DynamoDB with naming convention: `terraform-state-{project-prefix}-{environment}-infra`
2.2. The system must use DynamoDB table for state locking with naming convention: `terraform-locks-{project-prefix}-{environment}-infra`
2.3. The system must enable state file encryption using AWS KMS

### 3. CloudFront Distribution Setup
3.1. The system must create a CloudFront distribution with PriceClass_100 exclusively
3.2. The system must configure default behavior to serve React application from S3 origin
3.3. The system must configure `/api/*` behavior to forward requests to Lambda function origin with no caching
3.4. The system must allow any origin requests for API health checks and React-to-API communication
3.5. The system must associate the SSL certificate ARN from Stage 01 input data
3.6. The system must configure custom domain name using the domain from project configuration

### 4. Lambda Function Deployment
4.1. The system must create Lambda functions using Node.js 20 runtime
4.2. The system must set configurable memory allocation (default 128MB, configurable via --memory parameter)
4.3. The system must set configurable timeout (default 15 seconds, configurable via --timeout parameter)
4.4. The system must deploy placeholder API code with health check endpoint at root path (`/`)
4.5. The system must deploy placeholder API code with echo test endpoint (`/echo`)
4.6. The system must configure appropriate IAM execution role from Stage 01 input data

### 5. S3 Bucket Configuration
5.1. The system must create S3 bucket for static asset hosting
5.2. The system must configure bucket for CloudFront origin access without versioning
5.3. The system must set appropriate bucket policies for CloudFront access
5.4. The system must deploy compiled placeholder React application assets to the bucket

### 6. Route 53 DNS Configuration
6.1. The system must create or update Route 53 A record to point custom domain to CloudFront distribution
6.2. The system must use the hosted zone ID from Stage 01 input data
6.3. The system must configure alias record for optimal performance and cost

### 7. Resource Tagging
7.1. The system must apply standardized tags to all created resources: `Project` and `Environment`
7.2. The system must use project prefix from configuration for `Project` tag value
7.3. The system must use environment code from configuration for `Environment` tag value

### 8. Monitoring and Logging
8.1. The system must enable CloudWatch logs for all Lambda functions
8.2. The system must configure CloudFront error logging if lightweight options are available
8.3. The system must set appropriate log retention policies

### 9. State Management and Validation
9.1. Each deployment step must check current resource state before attempting creation or modification
9.2. Each deployment step must validate successful completion before proceeding to next step
9.3. The system must support safe re-execution of deploy.sh script without causing resource conflicts
9.4. The system must generate enhanced output configuration file for Stage 03 consumption

### 10. End-to-End Validation
10.1. The system must perform curl test against the custom domain to validate React application HTML response
10.2. The system must validate API connectivity using the React application's built-in API test button functionality
10.3. The system must validate that CloudFront behaviors correctly route `/api/*` requests to Lambda functions
10.4. The system must confirm that health check endpoint (`/`) returns successful response with timestamp
10.5. The system must verify that echo endpoint (`/echo`) accepts and returns test payloads correctly

## Non-Goals (Out of Scope)

- **API Gateway Integration**: Direct API Gateway setup is not needed since APIs are accessed via CloudFront behaviors
- **Advanced Caching Strategies**: Beyond basic no-cache for API routes and standard caching for static assets
- **Environment Variables**: No Lambda environment variables configuration needed for this stage
- **S3 Versioning**: Bucket versioning is explicitly not required - assets will be replaced directly
- **Advanced Monitoring**: No custom metrics, alarms, or dashboards beyond basic CloudWatch logs
- **Security Hardening**: Advanced security configurations beyond basic SSL and IAM roles
- **Performance Optimization**: Beyond basic CloudFront configuration
- **Real Application Deployment**: Placeholder applications only - real applications deployed in later stages

## Design Considerations

### Terraform Module Structure
- Use modular Terraform configuration with separate modules for CloudFront, Lambda, S3, and Route 53
- Follow Terraform best practices for variable declarations and output definitions
- Implement proper resource dependencies to ensure correct creation order

### CloudFront Behavior Configuration
- Default behavior: `/` → S3 bucket (React app) with standard caching
- Custom behavior: `/api/*` → Lambda function with no caching, all HTTP methods allowed
- Ensure proper origin request policies for CORS handling

### Placeholder Application Requirements
- **Placeholder API**: Simple Node.js application with health check (`/`) and echo (`/echo`) endpoints
- **Placeholder React App**: Basic Vite-built React application with API connectivity test button
- Both applications should be functionally identical to their "real" counterparts but with different branding

## Technical Considerations

### Dependencies
- **Stage 01 Output**: Certificate ARN, IAM role ARNs, VPC configuration, hosted zone ID
- **AWS Services**: CloudFront, Lambda, S3, Route 53, CloudWatch
- **Tools**: Terraform >= 1.0, Node.js 20, AWS CLI

### Integration Points
- **Input**: Stage 01 output configuration file (`{project-prefix}-config-{environment}.json`) automatically copied from `../01-infra-foundation/output/` to current stage's `input/` folder
- **Baseline Configuration**: Uses Stage 01 data (project details, AWS accounts, VPC, certificates, IAM roles) as foundation
- **New Resources**: Creates CloudFront distribution, Lambda functions, S3 buckets, Route 53 DNS records
- **Output**: Enhanced configuration file combining Stage 01 data plus new Stage 02 infrastructure details for Stage 03 consumption
- **Data Flow**: Stage 03 will follow identical pattern - copying Stage 02 output to Stage 03 input and enhancing with application deployment details
- **Terraform State**: Remote backend in S3 with DynamoDB locking

### Validation Requirements
- Pre-deployment: Verify Stage 01 outputs exist and are valid
- During deployment: State-aware resource creation with existence checks
- Post-deployment: Comprehensive connectivity testing via curl and application functionality

## Success Metrics

### Technical Success Criteria
1. **Infrastructure Deployment**: All Terraform resources created successfully without errors
2. **Domain Accessibility**: Custom domain resolves and serves React application HTML
3. **API Connectivity**: Both health check and echo endpoints respond correctly via CloudFront behaviors
4. **React-API Integration**: React application's API test button successfully communicates with backend
5. **DNS Propagation**: Route 53 records properly configured and resolving to CloudFront distribution

### Operational Success Criteria
1. **Script Reliability**: Deploy script can be executed multiple times safely
2. **State Validation**: Each step validates current state before proceeding
3. **Error Handling**: Clear error messages and appropriate exit codes for troubleshooting
4. **Logging**: CloudWatch logs capturing Lambda execution details
5. **Configuration Output**: Valid output file generated for Stage 03 consumption

### Performance Targets
- **Deployment Time**: Complete stage execution in under 10 minutes
- **Domain Response**: Custom domain responds within 30 seconds of deployment completion
- **API Latency**: Health check endpoint responds in under 2 seconds

## Technical Architecture Clarification

### Lambda Integration Method
- **Direct CloudFront to Lambda**: Lambda functions are accessed directly via CloudFront behaviors using Lambda Function URLs
- **No API Gateway**: API Gateway is NOT used in this architecture as CloudFront behaviors provide the routing functionality
- **Cost Optimization**: This approach reduces latency and cost by eliminating the API Gateway layer
- **Function URLs**: Create Lambda Function URLs for direct CloudFront origin integration
- **CORS Configuration**: Configure appropriate CORS headers for React-to-API communication

### S3 Origin Access Control
- **Origin Access Control (OAC)**: Use CloudFront OAC (modern replacement for OAI) for secure S3 access
- **Bucket Policy**: Configure bucket policy to allow CloudFront distribution access only
- **Public Access**: Block all public access, route everything through CloudFront

### CloudWatch Log Group Naming Convention
- **Pattern**: `/aws/lambda/{project-prefix}-{environment}-{function-name}`
- **Example**: `/aws/lambda/thuapp-sbx-api-handler`
- **Retention**: Set appropriate log retention policies per functional requirements section 8.3

## Open Questions - RESOLVED

1. ~~Should the Lambda functions be deployed in specific VPC subnets~~
   **RESOLVED**: Lambda functions will use the VPC configuration specified in Stage 00 discovery and validated in Stage 01, ensuring consistency across the deployment pipeline.

2. ~~Are there specific CloudWatch log group naming conventions~~
   **RESOLVED**: Use pattern `/aws/lambda/{project-prefix}-{environment}-{function-name}`

3. ~~Should the S3 bucket have public read access~~
   **RESOLVED**: Use CloudFront Origin Access Control (OAC) with bucket policy allowing CloudFront distribution access only

4. Do we need to handle multiple domains (e.g., www and non-www variants) or just the single domain from configuration?
5. Should the curl validation tests include specific response content validation, or just HTTP status codes?