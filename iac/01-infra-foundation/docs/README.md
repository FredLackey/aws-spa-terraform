# 01-infra-foundation Stage

## Overview

The 01-infra-foundation stage establishes the foundational AWS infrastructure required for the SPA deployment pipeline. This stage creates and validates cross-account trust relationships, manages SSL certificates, validates Route 53 hosted zone accessibility, and prepares the infrastructure foundation for subsequent deployment stages.

**Implementation Approach**: This stage uses pure AWS CLI and bash scripting with no Terraform components, following the discovery-first pattern outlined in the product specification. The stage implements the standardized 5-step execution pattern defined in the product specification document.

## Purpose

This stage accomplishes the following key objectives:

1. **Cross-Account Trust**: Establishes IAM roles and trust relationships between infrastructure and hosting accounts
2. **SSL Certificate Management**: Discovers existing or creates new SSL certificates with DNS validation
3. **Infrastructure Validation**: Validates all created resources through automated testing
4. **Configuration Enhancement**: Generates enhanced configuration for stage 02 consumption
5. **Idempotent Execution**: Ensures stage can be safely re-executed multiple times

## Directory Structure

```
01-infra-foundation/
├── deploy.sh              # Main deployment script
├── destroy.sh             # Resource cleanup script
├── scripts/                # Modular function scripts
│   ├── utils.sh           # Common utility functions
│   ├── iam-operations.sh  # IAM role management functions
│   ├── certificate-operations.sh  # SSL certificate functions
│   └── validation-functions.sh    # Resource validation functions
├── config/                # Configuration templates
│   ├── trust-policy-template.json      # IAM trust policy template
│   └── iam-permissions-template.json   # IAM permissions template
├── input/                 # Input configurations (auto-populated)
├── output/                # Enhanced configurations for next stage
├── logs/                  # Execution logs
└── docs/                  # Documentation
    └── README.md          # This file
```

## Prerequisites

### Required Tools
- AWS CLI v2.x
- jq (JSON processor)
- bash 4.0+

### AWS Configuration
- Valid AWS SSO sessions for both infrastructure and hosting profiles
- Cross-account permissions for IAM and certificate operations
- Route 53 hosted zone access from infrastructure account

### Input Requirements
- Valid configuration file from stage 00-discovery
- Contains project details, AWS account information, and domain configuration

## Usage

### Deployment

```bash
# Auto-discover input from stage 00-discovery
./deploy.sh

# Use specific input file
./deploy.sh --input-file /path/to/config.json

# Display help
./deploy.sh --help
```

### Cleanup

```bash
# Safe destruction with dependency checks
./destroy.sh

# Use specific configuration file
./destroy.sh --input-file /path/to/config.json

# Force destruction (skip dependency checks)
./destroy.sh --force

# Display help
./destroy.sh --help
```

## Execution Pattern

The stage follows a standardized 5-step execution pattern:

### 1. Authentication
- Validates AWS SSO sessions for both infrastructure and hosting profiles
- Verifies account ID matches and user identity
- Checks for session expiration

### 2. State Evaluation
- Assesses current state of AWS resources
- Identifies existing IAM roles and certificates
- Validates VPC and hosted zone accessibility

### 3. Input Preparation
- Auto-discovers input file from stage 00-discovery output
- Validates JSON format and required fields
- Extracts configuration parameters

### 4. Infrastructure Operations
- **IAM Role Management**: Creates or validates cross-account IAM roles
- **SSL Certificate Management**: Discovers existing or creates new certificates
- **Resource Validation**: Tests all created resources

### 5. Output Generation
- Creates enhanced configuration combining input and new infrastructure data
- Generates properly formatted output for stage 02 consumption
- Includes metadata and validation status

## Resource Management

### IAM Roles

The stage creates cross-account IAM roles with the following characteristics:

- **Role Name**: `{project-prefix}-{environment}-cross-account-role`
- **Trust Policy**: Allows assumption from infrastructure account with external ID
- **Permissions**: Minimal permissions for certificate and VPC operations
- **Tags**: Project and Environment tags as specified in configuration

### SSL Certificates

Certificate management follows these principles:

- **Discovery First**: Searches for existing certificates by exact domain match
- **DNS Validation**: Uses Route 53 for automatic certificate validation
- **Exact Matching**: Only uses certificates with exact domain match (no wildcards)
- **Idempotent**: Reuses valid existing certificates

### Resource Tagging

All created resources are tagged with:
- **Project**: From configuration `project.prefix`
- **Environment**: From configuration `project.environment`

## Validation

The stage performs comprehensive validation:

### Authentication Validation
- AWS SSO session validity for both accounts
- Account ID verification
- User identity confirmation

### Infrastructure Validation
- VPC accessibility from hosting account
- Hosted zone accessibility from infrastructure account
- Cross-account role assumption testing
- Certificate accessibility verification

### Validation Report
The stage generates a comprehensive validation report showing:
- ✅ Passed validations
- ❌ Failed validations  
- ⚠️ Skipped validations (when resources not available)

## Configuration

### Input Configuration
Expected from stage 00-discovery:
```json
{
  "project": {
    "prefix": "myapp",
    "environment": "sbx",
    "region": "us-east-1"
  },
  "aws": {
    "infrastructure_profile": "infra-profile",
    "hosting_profile": "hosting-profile", 
    "infrastructure_account_id": "123456789012",
    "hosting_account_id": "123456789013"
  },
  "domain": "myapp.sbx.example.com",
  "vpc_id": "vpc-xxxxxxxxx"
}
```

### Output Configuration
Enhanced configuration for stage 02:
```json
{
  "project": {
    "prefix": "myapp",
    "environment": "sbx",
    "region": "us-east-1"
  },
  "aws": {
    "infrastructure_profile": "infra-profile",
    "hosting_profile": "hosting-profile", 
    "infrastructure_account_id": "123456789012",
    "hosting_account_id": "123456789013"
  },
  "domain": "myapp.sbx.example.com",
  "vpc_id": "vpc-xxxxxxxxx",
  "certificate_arn": "arn:aws:acm:us-east-1:123456789013:certificate/12345678-1234-1234-1234-123456789012",
  "cross_account_role_arn": "arn:aws:iam::123456789013:role/myapp-sbx-cross-account-role",
  "hosted_zone_id": "Z1234567890123"
}
```

## Logging

### Log Files
- **Location**: `logs/` directory
- **Naming**: `deploy-YYYYMMDD-HHMMSS.log` or `destroy-YYYYMMDD-HHMMSS.log`
- **Format**: Structured with timestamps and severity levels
- **Retention**: Keeps 10 most recent log files

### Log Levels
- **[INFO]**: General information and progress updates
- **[SUCCESS]**: Successful operations
- **[WARNING]**: Non-fatal issues or important notices
- **[ERROR]**: Failures that require attention

## Error Handling

### Common Issues

#### Authentication Failures
```
[ERROR] AWS SSO authentication failed
[ERROR] Please run: aws sso login --profile {profile-name}
```
**Resolution**: Run the suggested SSO login command

#### Certificate Validation Timeout
```
[ERROR] Certificate validation timeout reached
```
**Resolution**: Check DNS validation records in Route 53 and retry

#### Cross-Account Access Denied
```
[ERROR] Cross-account role assumption test failed
```
**Resolution**: Verify IAM role trust policy and permissions

### Remediation Steps

1. **Authentication Issues**: Refresh AWS SSO sessions
2. **Permission Errors**: Verify cross-account trust policies
3. **DNS Issues**: Check Route 53 hosted zone configuration
4. **Resource Conflicts**: Use idempotent re-execution

## Safety Features

### Idempotent Operations
- All operations can be safely re-executed
- Existing resources are validated rather than recreated
- Configuration drift is automatically corrected

### Dependency Validation
- Destruction checks for dependent stages
- Resources shared with other stages are preserved
- Force flag available for override when needed

### Resource Protection
- SSL certificates are not automatically deleted
- IAM roles are only removed if created by this stage
- Comprehensive logging for audit trail

## Integration

### Previous Stage (00-discovery)
- **Input**: Project and AWS account discovery data
- **Dependency**: Valid VPC and hosted zone configuration

### Next Stage (02-infra-setup)
- **Output**: Enhanced configuration with infrastructure foundation
- **Provides**: Cross-account IAM roles and SSL certificates

## Troubleshooting

### Debug Mode
Enable detailed logging by modifying the script:
```bash
set -x  # Add to scripts for detailed execution tracing
```

### Manual Verification
Verify resources manually:
```bash
# Check IAM role
aws iam get-role --role-name myapp-sbx-cross-account-role --profile hosting-profile

# Check certificate
aws acm list-certificates --profile hosting-profile

# Test role assumption
aws sts assume-role --role-arn "arn:aws:iam::ACCOUNT:role/ROLE" --role-session-name test --external-id "myapp-sbx" --profile infra-profile
```

### Common Resolutions
1. **Refresh SSO sessions** for authentication issues
2. **Check Route 53 configuration** for DNS validation failures
3. **Verify account IDs** in configuration files
4. **Review IAM permissions** for cross-account operations

## Security Considerations

### Principle of Least Privilege
- IAM roles have minimal required permissions
- External ID required for role assumption
- Time-limited credentials for testing

### Audit Trail
- All operations are logged with timestamps
- Resource creation and modification tracked
- Validation results recorded

### Cross-Account Security
- Trust policies restrict access to specific accounts
- External ID provides additional security layer
- Role sessions are named and tracked

## Performance

### Execution Time
- Typical execution: 5-15 minutes
- Certificate validation: Up to 30 minutes
- DNS propagation: Up to 5 minutes

### Optimization
- Parallel operations where possible
- Early exit on validation failures
- Efficient resource discovery

## Maintenance

### Log Cleanup
Automatic cleanup keeps 10 most recent log files per operation type.

### Configuration Updates
To update IAM policies or trust relationships:
1. Modify template files in `config/`
2. Re-run deployment script
3. Script will detect and apply changes

### Version Compatibility
Compatible with AWS CLI v2.x and standard bash utilities.