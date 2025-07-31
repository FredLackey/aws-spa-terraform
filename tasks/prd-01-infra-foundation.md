# Product Requirements Document: 01-infra-foundation Stage

## Introduction/Overview

The 01-infra-foundation stage establishes the foundational AWS infrastructure required for the SPA deployment pipeline. This stage creates and validates cross-account trust relationships, manages SSL certificates, validates Route 53 hosted zone accessibility, and prepares the infrastructure foundation for subsequent deployment stages. The stage operates on a "validate-before-create" principle, ensuring idempotent execution and safe re-runs.

**Implementation Approach**: This stage uses pure AWS CLI and bash scripting with no Terraform components, following the discovery-first pattern outlined in the product specification. The stage implements the standardized 5-step execution pattern defined in the product specification document.

**Problem Statement**: After project discovery (stage 00), the AWS accounts need foundational infrastructure configured to support secure, cross-account SPA deployment with proper SSL certificates and hosted zone validation.

**Goal**: Establish a validated, secure infrastructure foundation with cross-account trust, SSL certificates, and hosted zone validation ready for application deployment.

## Goals

1. **Establish Cross-Account Trust**: Create and validate IAM roles and trust relationships between infrastructure and hosting accounts
2. **SSL Certificate Management**: Discover existing or create new SSL certificates for the application domain using DNS validation
3. **Infrastructure Validation**: Validate all created resources through automated testing
4. **Configuration Enhancement**: Generate enhanced configuration for stage 02 consumption
5. **Idempotent Execution**: Ensure stage can be safely re-executed multiple times

## User Stories

**As an AWS Cloud Owner**, I want the stage to automatically establish trust relationships between my infrastructure and hosting accounts so that subsequent stages can deploy resources securely across accounts.

**As an AWS Cloud Owner**, I want SSL certificates to be discovered if they exist or created if they don't, so that my application will have proper HTTPS support without manual certificate management.

**As an AWS Cloud Owner**, I want the stage to validate each resource after creation so that I can be confident the infrastructure foundation is working correctly before proceeding to the next stage.

**As an AWS Cloud Owner**, I want the stage to be re-runnable so that if something fails, I can fix the issue and re-execute without side effects.

## Functional Requirements

### Cross-Account Trust Management
1. The system must validate if cross-account IAM roles already exist between infrastructure and hosting accounts
2. The system must create missing IAM roles required for cross-account resource management
3. The system must validate if trust policies are correctly configured
4. The system must update misconfigured trust policies to match required specifications
5. The system must test cross-account assume role functionality using AWS CLI commands
6. The system must store created role ARNs in the output configuration

### SSL Certificate Management
7. The system must search for existing SSL certificates in AWS Certificate Manager for the exact application domain
8. The system must use existing certificates if the FQDN matches exactly (no wildcards)
9. The system must create new SSL certificates using DNS validation if no matching certificate exists
10. The system must wait for certificate validation to complete before proceeding
11. The system must store the certificate ARN in the output configuration
12. The system must validate certificate status using AWS CLI commands

### Route 53 Hosted Zone Management
13. The system must validate that the hosted zone exists (inherited from stage 00)
14. The system must ensure hosted zone is accessible from infrastructure account
15. The system must store hosted zone details in the output configuration for subsequent stages

### Resource Validation
16. The system must test each created resource immediately after creation using AWS CLI commands
17. The system must validate cross-account access by attempting to assume roles
18. The system must validate SSL certificate accessibility from both accounts
19. The system must validate hosted zone accessibility from infrastructure account
20. The system must report validation results in logs with clear success/failure status

### Configuration Management
21. The system must automatically copy output file from `../00-discovery/output/` to `input/` folder (unless `--input-file` is specified)
22. The system must accept optional `--input-file` argument to specify path to output file from previous stage
23. The system must copy the specified output file to the `input/` folder before processing
24. The system must load and validate the input configuration before proceeding, extracting environment code and region from the configuration file
25. The system must enhance the configuration with newly created resource identifiers
26. The system must create output configuration file for stage 02 consumption
27. The system must preserve all previous stage data while combining it with new infrastructure foundation data

### Documentation Requirements
28. The system must create a comprehensive README document in the `docs/` folder explaining stage 01 functionality
29. The README must include stage overview, purpose, owner, prerequisites, usage examples, and configuration details
30. The README must follow the same structure and format as the 00-discovery stage README document
31. The README must document all command-line arguments, validation steps, and output configurations
32. The README must provide troubleshooting guidance and common failure scenarios with remediation steps

### Error Handling and Authentication
33. The system must validate AWS SSO authentication for both infrastructure and hosting account profiles before starting
34. The system must invoke SSO login process automatically if authentication is not valid
35. The system must check VPC accessibility in the hosting account (VPC confirmed to exist from stage 00)
36. The system must fail fast with clear error messages if prerequisites are missing
37. The system must provide remediation instructions for common failure scenarios
38. The system must skip completed steps when re-executed after partial failures

### Resource Tagging
39. The system must apply mandatory tags to ALL created AWS resources:
    - `Project`: Set to the project prefix value from configuration
    - `Environment`: Set to the environment code (SBX, DEV, TEST, UAT, STAGE, MO, PROD) - uppercase for internal values
40. The system must ensure tag consistency across all resources within the stage
41. The system must validate that required tags are applied to all created resources

## Non-Goals (Out of Scope)

- **Security Baseline Components**: No CloudTrail, Config, GuardDuty, or other security services
- **KMS Key Management**: No encryption key creation or management
- **DNS Record Creation**: DNS records for application domain will be created in stage 02 when CloudFront distribution exists
- **Wildcard Certificates**: Only exact FQDN matching certificates
- **Multi-Region Support**: Single region deployment only
- **VPC Creation**: VPC must exist in hosting account (confirmed in stage 00)
- **Application Deployment**: No application code or Lambda deployment
- **Monitoring Setup**: No CloudWatch or alerting configuration
- **Backup/DR**: No disaster recovery configuration

## Technical Considerations

### AWS Services Integration
- **IAM**: Cross-account role discovery, creation, and trust policy management via AWS CLI
- **Certificate Manager**: SSL certificate discovery and creation with DNS validation via AWS CLI
- **Route 53**: Hosted zone validation and DNS validation record management specifically for certificate validation via AWS CLI
- **STS**: Cross-account role assumption testing and authentication validation via AWS CLI

### Dependencies
- Requires successful completion of stage 00-discovery
- VPC ID confirmed to exist in hosting account (validated in stage 00)
- Route 53 hosted zone must exist in infrastructure account
- Both AWS profiles (infrastructure and hosting accounts) must have active SSO sessions
- Region information available from stage 00 configuration

### Input/Output Format
- **Input**: JSON configuration from stage 00-discovery (containing project prefix, environment, accounts, VPC ID, domain, region)
- **Output**: Enhanced JSON configuration combining input data with new infrastructure foundation data
- **Configuration Enhancement**: New data includes certificate ARNs, IAM role ARNs, hosted zone details
- **Data Combination**: Previous stage data preserved and merged with current stage outputs
- **Logging**: Structured logs with validation results and timestamps

### Directory Structure Standards
All created resources and folders must follow the standardized pattern:
- **Resource Organization**: `{project-prefix}/{environment}` hierarchy
- **Consistent Nesting**: Applied uniformly across all AWS resources
- **Local Directory Structure**: Stage folders organized by project and environment
- **Predictable Paths**: Enables automated discovery and management of resources

### AWS CLI Workflow Requirements
The deployment script must implement the following discovery-first approach:

**IAM Role Management:**
1. Check if cross-account role exists using `aws iam get-role`
2. If role exists, validate trust policy configuration
3. If trust policy is misconfigured, update using `aws iam put-role-policy`
4. If role doesn't exist, create using `aws iam create-role`
5. Apply mandatory tags using `aws iam tag-role`
6. Test role assumption using `aws sts assume-role`

**Certificate Management:**
1. Search for existing certificates using `aws acm list-certificates` with domain filter
2. If exact domain match found, validate certificate status
3. If no matching certificate exists, create using `aws acm request-certificate`
4. If certificate requires DNS validation, handle certificate validation records in Route 53
5. Wait for certificate validation completion using polling logic
6. Store certificate ARN in output configuration

**Hosted Zone Validation:**
1. Validate hosted zone accessibility using `aws route53 get-hosted-zone`
2. Confirm cross-account permissions for infrastructure account
3. Store hosted zone details for subsequent stages

### Stage Folder Structure
This stage implements the standardized folder structure defined in the product specification, with explicit exclusion of Terraform components:

```
01-infra-foundation/
├── scripts/          # AWS CLI deployment scripts and helper functions
├── config/           # Stage-specific configuration files and templates
├── input/            # Input data from previous stage (00-discovery)
├── output/           # Output data for next stage consumption (02-infra-setup)
├── logs/             # Stage execution logs
├── docs/             # Stage-specific documentation
├── deploy.sh         # Stage deployment script
└── destroy.sh        # Stage destruction script
```

**Note**: The `terraform/` folder specified in the product specification standard is explicitly excluded from this stage as no Terraform components are used. This stage uses pure AWS CLI and bash scripting only.

**Folder Purposes:**
- **scripts/**: Core bash scripts for AWS CLI operations, validation functions, and resource discovery logic
- **config/**: Stage-specific configuration templates, IAM trust policy documents, and static files
- **input/**: Automatically populated with previous stage's output configuration
- **output/**: Contains enhanced configuration for next stage consumption
- **logs/**: All execution logs with timestamp-based naming
- **docs/**: Stage-specific documentation and README files

## Success Metrics

### Functional Success
- 100% of required IAM roles created and validated
- SSL certificate available and validated for the application domain
- Hosted zone accessibility confirmed from infrastructure account
- Cross-account role assumption working successfully
- All validation tests passing

### Operational Success
- Stage completes successfully with proper validation
- Stage can be re-executed safely without errors
- Clear success/failure reporting for each component
- Enhanced configuration file created for next stage

### Quality Metrics
- Zero manual intervention required during execution
- All resources properly tagged with mandatory Project and Environment tags via AWS CLI
- Comprehensive logging for troubleshooting with structured output
- Clear remediation guidance for failures with specific AWS CLI error handling
- Proper SSO authentication validation before execution
- Idempotent execution - safe to re-run multiple times without side effects

## Open Questions

1. **Trust Policy Specifics**: What are the exact IAM permissions required for the cross-account roles? (Note: This should be derived from AWS best practices for the services used in subsequent stages)

2. **Validation Timeouts**: What are the appropriate timeout values for certificate validation?

3. **Resource Naming**: Should the cross-account role names follow the same `{project-prefix}/{environment}` pattern as other resources?

4. **Rollback Strategy**: If the stage fails after creating some resources, should it attempt automatic cleanup or leave resources for manual inspection?

## Implementation Notes

### Entry Points
- `deploy.sh` - Main deployment script following product specification execution pattern
- `destroy.sh` - Cleanup script for AWS resources (**Note**: No Terraform components to destroy in this stage)

### Required Arguments
- Optional: `--input-file`: Path to output file from previous stage (if not using automatic discovery from ../00-discovery/output/)

**Note**: Following the progressive configuration enhancement pattern from the product specification, environment code and region are automatically retrieved from the previous stage's output configuration file. No baseline parameters need re-specification as these values are inherited from the 00-discovery stage output. This stage only accepts arguments for stage-specific functionality not covered by inherited configuration.

### AWS CLI Implementation Structure
- Pure AWS CLI and bash scripting approach for idempotent resource discovery and creation
- **No Terraform usage**: This stage explicitly does not use Terraform for any operations
- **No Terraform state management**: No Terraform state files created or managed
- Resource discovery logic with fallback to creation when resources don't exist
- Cross-account operations handled through AWS CLI profile switching
- All resource tagging implemented via AWS CLI commands with mandatory Project and Environment tags
- Follows the standardized 5-step execution pattern from the product specification:
  1. Authentication Validation
  2. Stage State Evaluation  
  3. Input Data Preparation
  4. Infrastructure Discovery/Creation
  5. Output Generation

### AWS CLI Operations and Validation
- `aws sts get-caller-identity` for SSO authentication validation
- `aws iam get-role` for IAM role discovery and validation
- `aws iam create-role` for cross-account role creation when needed
- `aws iam put-role-policy` for trust policy updates if misconfigured
- `aws sts assume-role` for cross-account trust testing
- `aws acm list-certificates` for SSL certificate discovery by domain
- `aws acm request-certificate` for certificate creation with DNS validation
- `aws acm describe-certificate` for certificate status validation
- `aws route53 get-hosted-zone` for hosted zone accessibility validation
- `aws route53 change-resource-record-sets` for certificate DNS validation records (if needed)

### Configuration Schema Example
The stage will enhance the input configuration with new infrastructure foundation data:

```json
{
  "project": {
    "prefix": "myapp",
    "environment": "DEV",
    "region": "us-east-1"
  },
  "accounts": {
    "infrastructure": "123456789012",
    "hosting": "210987654321"
  },
  "domain": "app.dev.example.com",
  "vpc": {
    "id": "vpc-12345"
  },
  "infrastructure": {
    "crossAccountRole": {
      "arn": "arn:aws:iam::210987654321:role/myapp-dev-cross-account-role",
      "created": true
    },
    "certificate": {
      "arn": "arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012",
      "status": "ISSUED",
      "domain": "app.dev.example.com"
    },
    "hostedZone": {
      "id": "Z1234567890ABC",
      "accessible": true,
      "domain": "dev.example.com"
    }
  }
}
```