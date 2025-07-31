# Stage 02: Infrastructure Setup

## Overview

Stage 02: Infrastructure Setup creates the core application infrastructure components required to host a Single Page Application (SPA) using AWS serverless services. This stage uses AWS CLI and bash scripting to provision CloudFront CDN, Lambda functions, and S3 storage, following the same patterns established in Stages 00 and 01.

## What This Stage Does

- **Creates S3 Bucket**: Static website hosting for React frontend assets
- **Creates Lambda Function**: Serverless backend API execution 
- **Creates CloudFront Distribution**: Global CDN with custom domain and SSL
- **Configures Routing**: CloudFront behaviors for `/` → S3 and `/api/*` → Lambda
- **Deploys Applications**: Compiles and deploys placeholder React and API applications
- **Validates Infrastructure**: End-to-end testing to ensure everything works

## Architecture Created

```
Custom Domain (HTTPS) → CloudFront Distribution
                            ├── / → S3 Bucket (React App)
                            └── /api/* → Lambda Function (API)
```

## Prerequisites

- Stage 00 (Discovery) completed successfully
- Stage 01 (Infrastructure Foundation) completed successfully
- AWS CLI v2 configured with appropriate permissions
- Node.js >= 20.0 for application building
- npm package manager

## Usage

### Deploy Infrastructure

```bash
# Basic deployment with defaults
./deploy.sh

# With optional parameters
./deploy.sh --cdn-price-class PriceClass_All --lambda-memory 512

# Using custom input file
./deploy.sh --input-file /path/to/config.json
```

### Destroy Infrastructure

```bash
# Remove all resources created by this stage
./destroy.sh
```

### Parameters

- `--cdn-price-class`: CloudFront price class (default: PriceClass_100)
  - Options: PriceClass_100, PriceClass_200, PriceClass_All
- `--lambda-memory`: Lambda memory in MB (default: 128)
  - Range: 128-10240 MB
- `--input-file`: Custom input configuration file path
- `--help`: Show usage information

## What Gets Created

### AWS Resources

1. **S3 Bucket**: `{project-prefix}-webapp-{environment}-{suffix}`
   - Static website hosting enabled
   - Public read access for web content
   - Bucket policy for CloudFront access

2. **Lambda Function**: `{project-prefix}-api-{environment}`
   - Node.js 20.x runtime
   - Configurable memory allocation
   - Basic execution role

3. **CloudFront Distribution**
   - Custom domain with SSL certificate (from Stage 01)
   - Optimized caching policies
   - Behavior routing for SPA architecture

### Applications Deployed

- **Placeholder React App**: From `/packages/placeholder-react-app/`
- **Placeholder API**: From `/packages/placeholder-api/`

## Validation

The stage performs comprehensive validation:

- **Infrastructure Validation**: Confirms all AWS resources are created and properly configured
- **Application Validation**: Tests that applications are accessible via CloudFront
- **End-to-End Testing**: Uses curl to verify complete request flow

## Output

Creates enhanced configuration file at `output/{project-prefix}-config-{environment}.json` containing:
- All input configuration from Stage 01 (preserved)
- Additional S3 bucket details (name, ARN, website URL)
- Additional Lambda function details (name, ARN)
- Additional CloudFront distribution details (ID, ARN, domain)
- Additional application URL for testing

## Troubleshooting

### Common Issues

1. **CloudFront Deployment Delays**: Distribution deployment can take 15-20 minutes
2. **Application Build Failures**: Check Node.js version and npm dependencies
3. **Permission Errors**: Verify AWS CLI authentication and cross-account role access

### Recovery

- Re-run `./deploy.sh` after fixing issues - the script is idempotent
- Check logs in `logs/` directory for detailed error information
- Use `./destroy.sh` to clean up and start fresh if needed

## Files and Directories

- `deploy.sh`: Main deployment script
- `destroy.sh`: Main destruction script
- `requirements.md`: Detailed requirements and specifications
- `scripts/`: Modular bash functions for AWS operations
- `input/`: Configuration from Stage 01
- `output/`: Enhanced configuration for Stage 03
- `logs/`: Execution logs and audit trails

For detailed technical requirements and specifications, see [REQUIREMENTS.md](REQUIREMENTS.md).