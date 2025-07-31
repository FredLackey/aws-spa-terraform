# AWS SPA Terraform Monorepo - Product Specification

## Overview

This monorepo demonstrates best practices for deploying a Single Page Application (SPA) to AWS using a comprehensive Infrastructure as Code (IaC) approach. The project showcases a complete end-to-end deployment pipeline using Terraform, AWS CLI, and bash automation scripts.

## Purpose

The primary purpose of this monorepo is to provide a production-ready template and reference implementation for:

1. **Multi-tier AWS architecture deployment** - Demonstrating proper separation between infrastructure and hosting AWS accounts
2. **Modern web application stack** - Node.js API backend with React.js frontend
3. **AWS serverless deployment** - Utilizing CloudFront CDN and Lambda functions for optimal performance and cost
4. **Infrastructure as Code best practices** - Terraform modules, state management, and automated deployment scripts
5. **Multi-stage deployment workflow** - Development, staging, and production environments

## Inter-Stage Data Flow Architecture

The monorepo implements a **progressive configuration enhancement pattern** where each stage builds upon the validated data from previous stages:

### Data Flow Pattern
1. **Stage N Completion**: Creates `output/{project-prefix}-config-{environment}.json` with validated configuration
2. **Stage N+1 Initialization**: 
   - Automatically copies `../stage-N/output/{project-prefix}-config-{environment}.json` to `input/{project-prefix}-config-{environment}.json`
   - Loads existing configuration as baseline
3. **Stage N+1 Enhancement**:
   - Accepts additional parameters via command line arguments
   - Validates new parameters against existing configuration
   - Adds new stage-specific data directly to the existing configuration structure
4. **Stage N+1 Completion**: Creates enhanced `output/{project-prefix}-config-{environment}.json` with all previous data plus new additions

### Configuration Evolution Example
```bash
# Stage 00-discovery - Collect ALL required baseline parameters
./deploy.sh -e DEV -p myapp -i infra-profile -h hosting-profile -d app.dev.example.com --vpc-id vpc-12345
# Creates: output/myapp-config-dev.json (complete project config with VPC)

# Stage 01-infra-foundation - Discover/create infrastructure resources
./deploy.sh
# 1. Copies: ../00-discovery/output/myapp-config-dev.json → input/myapp-config-dev.json
# 2. Extracts environment (DEV) and region from input configuration
# 3. Uses VPC ID from discovery config
# 4. Discovers existing SSL certificate OR creates new certificate for domain
# 5. Creates: output/myapp-config-dev.json (enhanced with certificate ARN, cross-account role ARN, hosted zone ID)

# Stage 02-infra-setup - Configure application infrastructure (AWS CLI)
./deploy.sh --cdn-price-class PriceClass_100 --lambda-memory 512
# 1. Copies: ../01-infra-foundation/output/myapp-config-dev.json → input/myapp-config-dev.json
# 2. Extracts environment (DEV) and region from input configuration
# 3. Uses AWS CLI to create CloudFront, Lambda, and S3 resources
# 4. Deploys placeholder applications for infrastructure testing
# 5. Creates: output/myapp-config-dev.json (enhanced with S3, Lambda, CloudFront details and application URL)
```

### Flexible Input Sourcing
Each stage supports an optional `--input-file` argument for custom input sources:
```bash
# Use specific output file from previous stage instead of automatic discovery
./deploy.sh --input-file /path/to/myapp-config-dev.json --additional-stage-params

# Use archived output file from previous stage
./deploy.sh --input-file s3://archive/myapp-config-dev-backup.json
```

### Benefits
- **Progressive Validation**: Each stage validates compatibility with previous stage data
- **Configuration Inheritance**: Environment, region, and baseline parameters never need re-specification after stage 00
- **Configuration Consistency**: Same project prefix + environment maintains data relationships
- **Pipeline Flexibility**: Stages can be re-run with different stage-specific parameters while preserving base configuration
- **Data Lineage**: Clear traceability of configuration evolution through deployment pipeline
- **Recovery Support**: Previous stage outputs enable pipeline restart from any point

## Design Principles

The following principles guide all implementation decisions throughout the monorepo:

### Data Format Standardization
- **JSON Format**: All data exchange between stages uses JSON format exclusively
  - Output folder contents stored as JSON files
  - Input folder data consumed as JSON files
  - Configuration files maintained in JSON format
  - Ensures consistent parsing and validation across all stages

### AWS Resource Tagging
- **Mandatory Tagging**: All AWS resources created must include standardized tags
  - `Project`: Project prefix value for resource identification
  - `Environment`: Environment code (SBX, DEV, TEST, UAT, STAGE, MO, PROD) - uppercase for internal values
  - Additional tags may be added as needed for specific resources
- **Tag Consistency**: Tags applied uniformly across all stages and environments
- **Cost Tracking**: Enables accurate cost allocation and resource management

### Infrastructure as Code Standards  
- **Stage-Appropriate Tooling**: 
  - Stages 00-discovery, 01-infra-foundation, and 02-infra-setup use pure AWS CLI and bash scripting
  - Stages 03+ use Terraform for application deployment and management
- **State Management**: 
  - AWS CLI stages (00, 01, 02) use JSON configuration files for state tracking
  - Terraform stages (03+) maintain independent Terraform state files
- **Folder Structure**: The `terraform/` folder is excluded from stages that use pure AWS CLI
- **Idempotent Operations**: All deployment operations can be safely re-executed

### State-Aware Execution
- **Existence Validation**: Always check if resources exist before attempting creation
- **Update Detection**: Evaluate whether existing resources require modification
- **Stage 01 Discovery Pattern**: Use AWS CLI with discovery-first approach for foundational resources
- **Terraform Integration**: Leverage Terraform's built-in state management for application deployment (Stage 03+)
- **No Redundant Operations**: Skip unnecessary operations when desired state already exists
- **Safe Re-execution**: All scripts can be run multiple times without adverse effects

### Security and Access Control
- **SSO Authentication**: All operations require AWS SSO authentication before execution
- **Authentication Validation**: SSO validation occurs as first step in deploy.sh and destroy.sh
- **Least Privilege**: IAM roles and policies follow principle of least privilege
- **Cross-Account Trust**: Secure trust relationships between infrastructure accounts
- **No Hardcoded Secrets**: All sensitive data passed through secure configuration mechanisms

### Entry Point Standardization
- **Standard Entry Points**: Only `deploy.sh` and `destroy.sh` serve as human entry points
- **No Alternative Names**: Avoid common practices like `bootstrap.sh`, `init.sh`, `configure.sh`
- **Consistent Interface**: All stages use identical entry point naming conventions

### Directory Structure Standards
- **Project-Environment Hierarchy**: All created folders follow `{project-prefix}/{environment}` structure
- **Consistent Nesting**: Applied uniformly across all AWS resources and local directories
- **Predictable Paths**: Enables automated discovery and management of resources

## Target Audience & User Personas

This monorepo is designed for organizations with three distinct roles:

### 1. AWS Cloud Owner
- **Responsibility**: Account governance, security, and foundational AWS setup
- **Focus**: Cross-account permissions, DNS management, certificate provisioning
- **Access Level**: Administrative access to AWS Organizations and root accounts

### 2. DevOps Team
- **Responsibility**: Infrastructure automation and developer enablement
- **Focus**: Terraform modules, CI/CD pipelines, application infrastructure
- **Access Level**: Deployment permissions within hosting accounts

### 3. Developer Community
- **Responsibility**: Application development and deployment
- **Focus**: Business logic, code deployment, application testing
- **Access Level**: Deployment tools and monitoring dashboards

*For detailed persona definitions, see [User Personas documentation](user-personas.md)*

## Key Components

### 1. Sample Applications
- **Placeholder API** - Demo Node.js backend for DevOps team infrastructure setup and testing
- **Placeholder React App** - Demo React.js frontend for DevOps team CloudFront configuration
- **Real API** - Production Node.js backend service with Lambda deployment configuration
- **Real React App** - Production React.js frontend application optimized for CloudFront distribution

### 2. Infrastructure as Code
- **IAC directory** - Organized deployment stages and scripting stages
- **Multi-stage configuration** - Environment-specific deployments
- **State management** - Remote state with proper locking mechanisms

### 3. AWS Services Integration
- **CloudFront** - Global CDN for frontend distribution
- **Lambda** - Serverless API hosting
- **API Gateway** - RESTful API management
- **S3** - Static asset hosting and Terraform state storage
- **Route 53** - DNS management
- **Certificate Manager** - SSL/TLS certificate provisioning

### 4. Automation & Tooling
- **IAC orchestration** - All AWS CLI and Terraform operations organized by deployment stages
- **AWS CLI integration** - Account validation and resource management via automated commands
- **Terraform automation** - Infrastructure as Code executed through structured deployment stages
- **CI/CD ready** - GitHub Actions compatible deployment workflows

## Architecture Overview

### Multi-Account Strategy
The project implements a two-account approach:

1. **Infrastructure Account** - Hosts shared services, monitoring, and security resources
2. **Hosting Account** - Contains application-specific resources and environments

### Deployment Flow by Persona
```
AWS Cloud Owner: [Account Creation] → [DNS Setup] → [Cross-Account IAM] → [Certificates]
                                ↓
DevOps Team:     [Terraform Modules] → [Infrastructure] → [Sample Apps] → [CI/CD]
                                ↓
Developers:      [Code Development] → [Application Deployment] → [Testing] → [Monitoring]
```

## Project Structure

```
aws-spa-terraform/
├── docs/                     # Documentation
├── packages/
│   ├── placeholder-api/      # Demo Node.js backend for DevOps team
│   ├── placeholder-react-app/# Demo React.js frontend for DevOps team
│   ├── real-api/            # Production Node.js backend for Development team
│   └── real-react-app/      # Production React.js frontend for Development team
├── iac/                      # Infrastructure as Code
│   ├── [stage]/              # Deployment stage folder (00-discovery, 01-infra-foundation, etc.)
│   │   ├── terraform/        # Terraform configurations (stages 02+ only - excluded from stages using pure AWS CLI)
│   │   ├── scripts/          # Deployment scripts
│   │   ├── config/           # Stage-specific configuration files
│   │   ├── input/            # Input data from previous stage
│   │   ├── output/           # Output data for next stage consumption
│   │   ├── logs/             # Stage execution logs
│   │   ├── docs/             # Stage-specific documentation
│   │   ├── deploy.sh         # Stage deployment script
│   │   └── destroy.sh        # Stage destruction script
└── config/                   # Configuration files
```

## Stage Script Functionality

### deploy.sh (Generic Stage Deployment)
Each stage's `deploy.sh` script follows a standardized execution pattern:

1. **Authentication Validation**
   - Test current AWS profiles to ensure user is properly logged in
   - Validate required permissions for the stage operations
   - Fail early if authentication is insufficient

2. **Stage State Evaluation**
   - Check if stage deployment has already been executed successfully
   - Evaluate current infrastructure state against expected stage outcomes
   - Skip execution if stage is already in desired state, or proceed if updates are needed
   - Log evaluation results for audit purposes

3. **Input Data Preparation**
   - Copy output data from previous stage's `output/` folder to current stage's `input/` folder
   - Validate required input data exists and is properly formatted
   - Set up stage-specific configuration variables

4. **Infrastructure Deployment**
   - Execute Terraform plan and apply operations
   - Run any additional deployment scripts required for the stage
   - Validate deployment success

5. **Output Generation**
   - Generate output data for consumption by subsequent stages
   - Store outputs in the current stage's `output/` folder
   - Log deployment results and status

### destroy.sh (Generic Stage Destruction)
Each stage's `destroy.sh` script provides cleanup functionality:

1. **Authentication Validation**
   - Test current AWS profiles to ensure user is properly logged in
   - Validate required permissions for destruction operations

2. **Stage State Evaluation**
   - Check if stage resources have already been destroyed
   - Evaluate current infrastructure state to determine if destruction is needed
   - Skip execution if stage is already destroyed, or proceed if resources exist
   - Log evaluation results for audit purposes

3. **Dependency Validation**
   - Check if subsequent stages depend on current stage resources
   - Warn user of potential impacts before proceeding with destruction

4. **Infrastructure Destruction**
   - For Terraform stages: Execute Terraform destroy operations in reverse dependency order
   - For AWS CLI stages: Execute AWS CLI delete operations for created resources
   - Clean up any additional resources not managed by the primary tooling
   - Validate complete resource removal

5. **State Management**
   - **Terraform stages**: By default, preserve Terraform state files in remote backend for future deployments
   - **Terraform stages**: Remove Terraform state files only if `--remove-tf` flag is explicitly passed
   - **AWS CLI stages**: No state files to manage - resource tracking via configuration files
   - If removing Terraform state files, clean up remote state backend resources
   - Log state management decisions for audit purposes

6. **Cleanup Operations**
   - Remove temporary files and local state artifacts
   - Log destruction results and status

## Script Argument Standards

All bash scripts in the IAC stages follow standardized argument handling:

### Argument Format
- **Double-dash format**: All arguments support `--argument-name` format
- **Single-dash format**: All arguments also support `-x` single character format
- **No interactive prompts**: Scripts never prompt for user input during execution
- **Explicit parameters**: All required values must be passed as arguments

### Error Handling
- **Missing arguments**: Display usage information and specific error message
- **Invalid arguments**: Show usage and explain which argument is invalid
- **Immediate exit**: Scripts exit with non-zero status on argument errors

### Example Usage Patterns

**Stage 00-discovery (baseline configuration):**
```bash
# Deploy script with double-dash arguments
./deploy.sh --environment DEV --region us-east-1 --project-prefix myapp --domain app.dev.example.com --vpc-id vpc-12345

# Deploy script with single-dash arguments  
./deploy.sh -e SBX -r us-east-1 -p myapp -d app.sbx.example.com -v vpc-67890
```

**Subsequent stages (01+) - inherit baseline configuration:**
```bash
# Deploy script using automatic input discovery
./deploy.sh

# Deploy script with custom input file
./deploy.sh --input-file /path/to/previous-stage-output.json

# Destroy script with Terraform state removal (Terraform stages only)
./destroy.sh --remove-tf

# Destroy script for AWS CLI stages (no Terraform state)
./destroy.sh
```

### Standard Arguments for Stage 00-discovery
The following arguments are required only for the initial discovery stage (00-discovery) to establish baseline configuration:
- `--environment` / `-e`: Target environment code (SBX, DEV, TEST, UAT, STAGE, MO, PROD) - accepts uppercase or lowercase, lowercase used for file names
- `--region` / `-r`: AWS region for deployment
- `--help` / `-h`: Display usage information

### Standard Arguments for Subsequent Stages (01+)
Later stages inherit baseline configuration and only accept stage-specific arguments:
- `--input-file`: Optional path to previous stage output file (if not using automatic discovery)
- `--remove-tf` / `-t`: (destroy only) Remove Terraform state files (Terraform stages only)
- `--help` / `-h`: Display usage information
- Stage-specific arguments as needed for new functionality

### Environment Standards

All environments follow standardized naming conventions for consistency across deployments:

| Environment | Code | Description |
|-------------|------|-------------|
| Sandbox | `SBX` | Experimental and testing environment |
| Development | `DEV` | Development environment for active coding |
| Test | `TEST` | Testing environment for QA validation |
| User Acceptance Testing | `UAT` | User acceptance testing environment |
| Staging | `STAGE` | Pre-production staging environment |
| Model Office | `MO` | Model office demonstration environment |
| Production | `PROD` | Live production environment |

**Usage Examples:**
```bash
# Deploy to sandbox environment
./deploy.sh -e SBX -r us-east-1

# Deploy to development environment  
./deploy.sh --environment DEV --region us-west-2

# Deploy to staging environment
./deploy.sh -e STAGE -r us-west-2

# Deploy to production environment
./deploy.sh -e PROD -r us-east-1
```

## Terraform Backend Standards

All Terraform configurations use a standardized remote backend architecture:

### Backend Architecture
- **S3 + DynamoDB**: All Terraform state uses S3 for storage with DynamoDB for state locking
- **Stage-specific backends**: Each deployment stage maintains its own dedicated Terraform backend
- **Environment isolation**: Separate backends for each environment (SBX, DEV, TEST, UAT, STAGE, MO, PROD)

### Backend Configuration
- **S3 Bucket**: Stores Terraform state files with versioning enabled
- **DynamoDB Table**: Provides state locking and consistency checking
- **Encryption**: All state files encrypted at rest using AWS KMS
- **Access Control**: Backend resources restricted to appropriate IAM roles

### Backend Naming Convention
```
S3 Bucket: terraform-state-{account-id}-{stage}-{environment}
DynamoDB Table: terraform-locks-{account-id}-{stage}-{environment}
```

### State File Organization
```
s3://bucket-name/
├── 02-infra-setup/
│   ├── sbx/terraform.tfstate
│   ├── dev/terraform.tfstate
│   ├── test/terraform.tfstate
│   ├── uat/terraform.tfstate
│   ├── stage/terraform.tfstate
│   ├── mo/terraform.tfstate
│   └── prod/terraform.tfstate
│   └── ...
```

## Success Criteria

A successful implementation will demonstrate:

1. **Automated deployment** from a single command
2. **Environment isolation** with proper resource segregation
3. **Security best practices** including IAM roles and policies
4. **Scalable architecture** capable of handling production workloads
5. **Cost optimization** through serverless and CDN usage
6. **Monitoring and logging** integration
7. **Documentation completeness** for onboarding new team members

## Technical Requirements

### Prerequisites
- AWS CLI configured with appropriate permissions
- Terraform >= 1.0
- Node.js >= 20.0
- npm or yarn package manager
- Git for version control

### AWS Permissions
The deployment requires permissions for:
- CloudFormation stack management
- Lambda function deployment
- CloudFront distribution management
- S3 bucket operations
- IAM role and policy management
- Route 53 DNS operations
- Certificate Manager operations

## Implementation Stages by Persona

### Stage 0: Discovery (00-discovery)
**Formal Name**: 00-discovery
**Owner**: Project Lead / AWS Cloud Owner
- Project configuration initialization
  - Collect project prefix for resource naming conventions
  - Gather domain names for CloudFront applications (placeholder and real apps)
  - Define environment specifications (SBX, DEV, TEST, UAT, STAGE, MO, PROD)
  - Configure AWS account IDs for infrastructure and hosting accounts
  - Specify target VPC ID for single-VPC deployment
  - Define target AWS region for single-region deployment
- Generate configuration files for subsequent stages
- Validate domain ownership and DNS requirements
- Create initial project structure and configuration templates

### Stage 1: Infrastructure Foundation (01-infra-foundation)
**Formal Name**: 01-infra-foundation
**Owner**: AWS Cloud Owner
**Implementation**: Pure AWS CLI and bash scripting (no Terraform)
- Trust relationship discovery and configuration
  - Discover existing cross-account trust policies via AWS CLI
  - Create missing trust relationships between infrastructure and hosting accounts
  - Validate and update trust policy permissions and scope
- SSL certificate discovery and management
  - Search for existing certificates matching application domain
  - Create new certificates with DNS validation if none exist
  - Handle certificate validation workflow
- Route 53 hosted zone validation and DNS record management for certificate validation
- Cross-account IAM role discovery, creation, and validation

### Stage 2: Infrastructure Setup (02-infra-setup)
**Formal Name**: 02-infra-setup
**Owner**: DevOps Team
**Implementation**: AWS CLI and bash scripting (following pattern from Stages 00-01)
- Application infrastructure creation (CloudFront, Lambda, S3 - no API Gateway needed)
- CloudFront behaviors configuration for SPA routing (/ → S3, /api/* → Lambda)
- Placeholder application compilation and deployment (React SPA and Node.js API)
- Resource validation and end-to-end testing
- JSON configuration enhancement for subsequent stages

### Stage 3: Application Deployment (03-app-deploy)
**Formal Name**: 03-app-deploy
**Owner**: DevOps Team (setup) + Developer Community (execution)
- Development environment provisioning
- Deployment script creation and testing
- Documentation and training materials
- Sample application deployment validation

### Stage 4: Production Deployment (04-prod-deploy)
**Formal Name**: 04-prod-deploy
**Owner**: Developer Community
- Replace sample applications with business logic
- Application testing and optimization
- Production deployment and monitoring
- Ongoing maintenance and updates

## Success Metrics

- **Deployment time** < 15 minutes for full environment
- **Zero-downtime deployments** for application updates
- **Cost efficiency** < $50/month for development environments
- **Security compliance** with AWS Well-Architected Framework
- **Documentation coverage** 100% of deployment procedures

## Out of Scope

This monorepo focuses exclusively on infrastructure deployment and does not include:

### CI/CD Pipelines
- **GitHub Actions workflows** - No automated pipeline configurations
- **Jenkins pipelines** - No continuous integration setup
- **Azure DevOps** - No pipeline-as-code implementations
- **GitLab CI** - No automated deployment workflows

### Secrets Management
- **AWS Secrets Manager** - No secret provisioning or rotation
- **HashiCorp Vault** - No external secret management integration
- **Environment variables** - No secret injection mechanisms
- **API keys and tokens** - No credential management systems
- **Key Rotation** - No automated key rotation mechanisms
- **Encryption Configuration** - No custom encryption key management or configuration

### Application Development
- **Business logic implementation** - Applications remain as basic demos
- **Database design** - No data modeling or migration scripts
- **Authentication systems** - No user management or OAuth implementation
- **Testing frameworks** - No unit, integration, or end-to-end tests

### Monitoring and Observability
- **CloudWatch** - No custom metrics, dashboards, or alarm configuration
- **X-Ray** - No distributed tracing implementation
- **Application Performance Monitoring** - No APM tool integration
- **Custom dashboards** - No Grafana or CloudWatch dashboard creation
- **Alerting systems** - No automated alert configuration
- **Log aggregation** - No centralized logging solutions

## Conclusion

This monorepo serves as a comprehensive reference for modern AWS SPA deployments, emphasizing automation, security, and scalability. It provides a solid foundation for teams looking to implement production-ready Infrastructure as Code practices in their AWS environments.