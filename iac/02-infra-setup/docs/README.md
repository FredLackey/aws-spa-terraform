# Stage 02 Infrastructure Setup

Complete SPA (Single Page Application) infrastructure deployment with CloudFront, Lambda, S3, and Route53.

## Overview

Stage 02 Infrastructure Setup deploys a production-ready web application infrastructure on AWS, including:

- **CloudFront Distribution**: Global CDN with custom domain and SSL
- **Lambda Functions**: Serverless API with Function URLs
- **S3 Bucket**: Static asset hosting for React application
- **Route 53 DNS**: Custom domain configuration
- **Monitoring & Logging**: CloudWatch integration

This stage builds upon Stage 01 (Foundation) by automatically discovering and using previously created resources like SSL certificates, VPC configuration, and IAM roles.

## Architecture

```
Internet → Route53 → CloudFront → [S3 (Static Assets) | Lambda (API)]
```

### Components

1. **CloudFront Distribution**
   - PriceClass_100 (cost-optimized)
   - Default behavior: serves React app from S3
   - `/api/*` behavior: forwards to Lambda Function URL
   - CORS configuration for React-to-API communication
   - SSL certificate integration

2. **Lambda Function**
   - Node.js 20 runtime
   - Configurable memory (128MB default)
   - Configurable timeout (15s default)
   - Function URLs for direct CloudFront integration
   - Health check (`/`) and echo (`/echo`) endpoints

3. **S3 Bucket**
   - Static asset hosting
   - CloudFront Origin Access Control (OAC)
   - Public access blocked
   - Automatic React app build and deployment

4. **Route 53 DNS**
   - A and AAAA records (IPv4 and IPv6)
   - Alias records to CloudFront
   - Automatic hosted zone discovery

## Prerequisites

- Stage 01 (Foundation) must be completed
- AWS CLI configured with appropriate profiles
- Terraform >= 1.0 installed
- Node.js and npm for React app builds
- jq for JSON processing

## Usage

### Configuration Discovery

Stage 02 automatically discovers configuration from Stage 01:

```bash
# Configuration is auto-copied from:
iac/01-infra-foundation/output/{project-prefix}-config-{environment}.json

# To:
iac/02-infra-setup/input/{project-prefix}-config-{environment}.json
```

### Basic Deployment

Deploy with default settings (128MB memory, 15s timeout):

```bash
cd iac/02-infra-setup
./deploy.sh
```

### Custom Lambda Configuration

Deploy with custom memory and timeout:

```bash
./deploy.sh --memory 256 --timeout 30
```

Or using short flags:

```bash
./deploy.sh -m 512 -t 60
```

### Parameter Validation

❌ **These parameters are NOT allowed** (auto-discovered):
```bash
./deploy.sh --environment dev    # ❌ ERROR
./deploy.sh --region us-west-2   # ❌ ERROR
```

### Infrastructure Destruction

```bash
./destroy.sh
```

**⚠️ Warning**: This will permanently delete all infrastructure and data.

## Validation

### Automated Testing

Run comprehensive validation tests:

```bash
./scripts/validation.sh
```

Tests include:
- React application accessibility
- API endpoint functionality
- CloudFront behavior routing
- DNS resolution
- SSL certificate validation
- Lambda function status
- S3 bucket accessibility
- Performance testing

### Manual Testing

1. **Application Access**: Open `https://{your-domain}` in browser
2. **API Testing**: Use React app's test button for API connectivity
3. **CloudFront Behaviors**: 
   - Root path serves React app
   - `/api/*` paths route to Lambda
4. **Monitoring**: Check CloudWatch logs for Lambda execution

## Outputs

Stage 02 generates an enhanced configuration file for Stage 03:

```json
{
  "project": {...},
  "aws": {...},
  "domain": "...",
  "foundation": {...},
  "setup": {
    "timestamp": "...",
    "infrastructure_complete": true,
    "cloudfront": {
      "distribution_domain": "...",
      "validation_complete": true
    },
    "lambda": {
      "function_url": "...",
      "validation_complete": true
    }
  }
}
```

### Key Outputs

- **Application URL**: `https://{domain}`
- **API Base URL**: `https://{domain}/api`
- **CloudFront Distribution ID**: For CloudWatch monitoring
- **Lambda Function Name**: For direct AWS console access
- **S3 Bucket Name**: For manual file uploads

## Troubleshooting

### Common Issues

#### 1. CloudFront Deployment Timeout
```
Issue: CloudFront distribution takes 15-20 minutes to deploy
Solution: Wait for deployment to complete, use AWS console to monitor
```

#### 2. DNS Propagation Delay
```
Issue: Domain not immediately accessible after deployment
Solution: DNS changes can take up to 48 hours to propagate globally
```

#### 3. Lambda Function URL CORS Issues
```
Issue: API calls from React app fail with CORS errors
Solution: Check CloudFront behavior configuration and Lambda CORS settings
```

#### 4. S3 Bucket Access Denied
```
Issue: React app files not accessible through CloudFront
Solution: Verify Origin Access Control (OAC) configuration
```

### Debug Commands

Check CloudFront distribution status:
```bash
aws cloudfront get-distribution --id {distribution-id}
```

Test Lambda function directly:
```bash
aws lambda invoke --function-name {function-name} response.json
```

Verify S3 bucket contents:
```bash
aws s3 ls s3://{bucket-name}/
```

Check Route 53 records:
```bash
aws route53 list-resource-record-sets --hosted-zone-id {zone-id}
```

### Log Locations

- **Deploy logs**: `logs/deploy-{timestamp}.log`
- **Destroy logs**: `logs/destroy-{timestamp}.log`
- **Lambda logs**: CloudWatch `/aws/lambda/{project-prefix}-{environment}-api`
- **Terraform state**: S3 bucket `{backend-bucket}` key `{project-prefix}/{environment}/02-infra-setup/terraform.tfstate`

## Configuration Reference

### Required Configuration (Auto-discovered)

| Parameter | Description | Source |
|-----------|-------------|---------|
| `project_prefix` | Project identifier | Stage 01 |
| `environment` | Environment name | Stage 01 |
| `region` | AWS region | Stage 01 |
| `domain` | Custom domain | Stage 01 |
| `certificate_arn` | SSL certificate ARN | Stage 01 |
| `vpc_id` | VPC ID for Lambda | Stage 01 |
| `cross_account_role_arn` | IAM role for hosting account | Stage 01 |

### Optional Parameters

| Parameter | Default | Range | Description |
|-----------|---------|-------|-------------|
| `--memory` / `-m` | 128 | 128-10240 | Lambda memory in MB |
| `--timeout` / `-t` | 15 | 1-900 | Lambda timeout in seconds |

### Resource Naming Conventions

- **S3 Bucket**: `{project-prefix}-{environment}-static-assets`
- **Lambda Function**: `{project-prefix}-{environment}-api`
- **CloudFront OAC**: `{project-prefix}-{environment}-s3-oac`
- **Lambda Execution Role**: `{project-prefix}-{environment}-lambda-execution-role`
- **CloudWatch Log Group**: `/aws/lambda/{project-prefix}-{environment}-api`

## Security Considerations

### S3 Bucket Security
- All public access blocked
- Access only through CloudFront OAC
- No direct internet access to bucket

### Lambda Security
- Minimal IAM permissions
- VPC integration when specified
- Function URLs with CORS restrictions

### CloudFront Security
- HTTPS redirect enforced
- Modern TLS versions only (TLSv1.2+)
- CORS headers properly configured

### DNS Security
- DNSSEC support through Route 53
- Alias records for optimal performance

## Performance Optimization

### CloudFront Caching
- Static assets: 1 year cache (31536000s)
- HTML files: 5 minutes cache (300s)
- API requests: No caching

### Lambda Optimization
- Proper memory allocation
- Timeout tuning
- Connection pooling for VPC functions

### S3 Optimization
- Compressed assets
- Proper MIME types
- Efficient file structure

## Cost Optimization

### CloudFront
- PriceClass_100 (North America & Europe only)
- Optimal caching strategy
- No unnecessary features enabled

### Lambda
- Right-sized memory allocation
- Efficient code structure
- Minimal execution time

### S3
- No versioning (unless required)
- Lifecycle policies (if needed)
- Standard storage class

## Next Steps

After successful Stage 02 deployment:

1. **Stage 03**: Deploy real applications and APIs
2. **Monitoring Setup**: Configure CloudWatch dashboards
3. **CI/CD Integration**: Automate deployments
4. **Backup Strategy**: Implement data protection
5. **Scaling Preparation**: Plan for traffic growth

## Support

For issues or questions:

1. Check validation script output
2. Review CloudWatch logs
3. Verify AWS console resources
4. Test with curl commands
5. Check DNS propagation status

Remember that DNS and CloudFront changes can take time to propagate globally.