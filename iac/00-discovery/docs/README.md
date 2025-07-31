# Stage 00-discovery

## Overview

Stage 00-discovery is the initial configuration and validation phase of the AWS SPA Terraform deployment pipeline. This stage **does NOT create any AWS resources** - it only collects project parameters, validates AWS access, and generates configuration files for subsequent deployment stages.

## Purpose

- Project configuration collection and validation
- AWS profile validation and SSO session management
- Domain validation via Route 53 hosted zone checks (read-only)
- Resource naming convention establishment
- Configuration template generation for downstream stages

## Owner

**Project Lead / AWS Cloud Owner** - Responsible for initial project setup and account configuration.

## Prerequisites

- AWS CLI installed and configured
- AWS SSO profiles configured for both infrastructure and hosting accounts
- Valid AWS credentials with appropriate permissions for read-only operations
- **Route 53 hosted zone REQUIRED** - Must exist in infrastructure account for the application domain

## Required Arguments

| Argument | Short | Description | Example |
|----------|-------|-------------|---------|
| `--environment` | `-e` | Environment code | `DEV`, `PROD`, `SBX` |
| `--region` | `-r` | AWS region | `us-east-1`, `us-west-2` |
| `--project-prefix` | `-p` | Project naming prefix | `myapp`, `webapp` |
| `--infra-profile` | `-i` | Infrastructure account AWS profile | `infrastructure-account` |
| `--hosting-profile` | `-h` | Hosting account AWS profile | `hosting-account` |
| `--domain` | `-d` | Application domain (FQDN) | `dev-app.example.com`, `app.example.com` |

## Usage Examples

### Deploy Stage (Discovery)
```bash
# Full argument names
./deploy.sh \
  --environment DEV \
  --region us-east-1 \
  --project-prefix myapp \
  --infra-profile infrastructure \
  --hosting-profile hosting \
  --domain dev-app.example.com

# Short argument names
./deploy.sh -e PROD -r us-west-2 -p myapp -i infra -h hosting -d app.example.com
```

### Destroy Stage (Cleanup)
```bash
# Clean up local configuration files
./destroy.sh --environment DEV --region us-east-1
./destroy.sh -e PROD -r us-west-2
```

## What This Stage Does

### 1. Argument Validation
- Validates all required command line arguments
- Checks environment code against allowed values
- Validates project prefix format (lowercase alphanumeric)

### 2. AWS Profile Management
- Tests AWS SSO session validity for both profiles
- Automatically triggers SSO login for expired sessions
- Extracts and validates account IDs
- Ensures profiles can access their respective accounts

### 3. Domain Validation (REQUIRED)
- **Validates Route 53 hosted zone exists** for the application domain in the infrastructure account
- **BLOCKS deployment if hosted zone is missing** - this is a hard requirement
- Subsequent stages will create DNS records and cannot proceed without the hosted zone
- **Does NOT create or modify any DNS resources**

### 4. Resource Naming Convention
- Generates standardized resource names using `{project-prefix}/{environment}` pattern
- Creates naming templates for subsequent stages
- Establishes consistent naming for all AWS resources

### 5. Configuration Generation
- Creates JSON configuration file for next stage consumption
- Generates complete project configuration with all validated parameters
- Provides resource naming templates for subsequent stages

## Generated Files

### Output Files
- `output/{project-prefix}-config-{environment}.json` - Configuration for next stage
- `logs/deploy-{date}.log` - Discovery execution logs
- `logs/destroy-{date}.log` - Cleanup execution logs

### Configuration Structure
```json
{
  "project": {
    "prefix": "myapp",
    "environment": "dev",
    "region": "us-east-1"
  },
  "aws": {
    "infrastructure_profile": "infrastructure-account",
    "hosting_profile": "hosting-account",
    "infrastructure_account_id": "111111111111",
    "hosting_account_id": "222222222222"
  },
  "domain": "dev-app.example.com",
  "terraform": {
    "backend_bucket": "terraform-state-111111111111-dev",
    "backend_table": "terraform-locks-111111111111-dev"
  },
  "resource_naming": {
    "local_path": "myapp/dev",
    "stage": "00-discovery"
  },
  "discovery": {
    "timestamp": "2024-01-15T10:30:00Z",
    "validation_complete": true
  }
}
```

## AWS Resources

### ❌ NO AWS Resources Created
This stage **does NOT create any AWS resources**. It only:
- Reads existing Route 53 hosted zones
- Validates AWS account access and permissions

### Read-Only Operations Performed
- `aws sts get-caller-identity` - Validate profiles and extract account IDs
- `aws route53 list-hosted-zones` - **VALIDATE** existing hosted zone for the application domain (REQUIRED)

## State Management

### No Terraform State
This stage does not use Terraform and has no state to manage.

### Destruction Behavior
- **Local files only**: Only removes local configuration files
- **No AWS resources**: No AWS resources to destroy
- **Dependencies**: Warns about dependent stages before cleanup

## Security Features

- No AWS resource creation or modification
- Read-only AWS operations only
- Profile-based authentication only
- No hardcoded credentials or secrets
- Comprehensive input validation

## Error Handling

- Validates all inputs before execution
- Tests AWS access before proceeding
- Provides detailed error messages
- Logs all operations for troubleshooting
- Fails fast on validation errors
- Graceful handling of missing dependencies

## Next Steps

After successful completion of stage 00-discovery:

1. **Review generated configuration file**: `output/{project-prefix}-config-{environment}.json`
2. **Verify all parameters**: Check that collected information is correct
3. **Proceed to stage 01-infra-foundation**: This stage will create actual AWS resources
4. **Use generated configuration**: Subsequent stages will consume the discovery output

## Troubleshooting

### Common Issues

1. **AWS Profile Issues**
   - **Problem**: Profile authentication fails
   - **Solution**: Run `aws sso login --profile <profile>` manually
   - **Check**: Verify profile configuration in `~/.aws/config`

2. **Domain Validation Failures**
   - **Problem**: Route 53 hosted zone not found for application domain
   - **Impact**: **BLOCKS deployment** - discovery stage will fail and exit
   - **Action**: **REQUIRED** - Create hosted zone for the domain in infrastructure account before retrying

3. **Permission Issues**
   - **Problem**: Insufficient permissions for read operations
   - **Solution**: Ensure profiles have Route 53, S3, and DynamoDB read permissions
   - **Check**: Verify IAM policies attached to profiles

4. **Configuration File Issues**
   - **Problem**: Generated configuration missing or corrupted
   - **Solution**: Re-run discovery stage with correct parameters
   - **Check**: Verify all required arguments are provided

### Log Files

Check log files in the `logs/` directory for detailed execution information:
- `deploy-{date}.log` - Discovery execution logs
- `destroy-{date}.log` - Cleanup execution logs

### Validation Checklist

Before proceeding to the next stage, verify:

- ✅ All AWS profiles authenticate successfully
- ✅ Account IDs extracted correctly
- ✅ **Route 53 hosted zone exists for application domain (REQUIRED)**
- ✅ Configuration file generated in `output/` directory
- ✅ No error messages in log files

## Key Differences from Other Stages

### Discovery Stage Characteristics
- **Read-only operations**: Only validates and collects information
- **No Terraform**: No infrastructure as code in this stage
- **No AWS resource creation**: Purely informational and validation
- **Fast execution**: Completes in seconds, not minutes
- **Prerequisite stage**: Required before all other stages

### What Makes This Different
Unlike subsequent stages, 00-discovery:
- Does not require existing infrastructure (except Route 53 hosted zone)
- Cannot break existing resources
- Has no dependencies on other stages
- Provides foundation for all subsequent stages
- Can be run multiple times safely without side effects
- **Will fail fast if required Route 53 hosted zone is missing**