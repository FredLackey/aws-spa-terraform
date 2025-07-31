# AWS SPA Terraform Monorepo

## What This Is

A **demonstration template** showing how to deploy a Single Page Application (SPA) to AWS using a structured, multi-stage approach. This repo provides a complete example of Infrastructure as Code (IaC) deployment using a hybrid approach: AWS CLI for foundational resource discovery and Terraform for application infrastructure.

## Key Features

- **Multi-stage deployment** - Organized stages from initial setup to production deployment
- **CloudFront + Lambda architecture** - React frontend via CloudFront CDN, Node.js API via Lambda
- **Cross-account AWS setup** - Demonstrates infrastructure and hosting account separation
- **Hybrid tooling approach** - AWS CLI for foundational discovery, Terraform for application infrastructure
- **Automated deployment scripts** - `deploy.sh` and `destroy.sh` for each stage
- **Multiple environments** - Support for dev, staging, production environments
- **Sample applications** - Placeholder and "real" apps for testing infrastructure

## What This Is NOT

- **A production application** - Sample apps are basic shells for infrastructure testing
- **A comprehensive AWS solution** - Focuses only on SPA deployment patterns
- **A CI/CD system** - No automated pipelines or workflows included
- **A monitoring/security framework** - Basic AWS services only

## Who This Is For

- **DevOps teams** learning AWS SPA deployment patterns
- **Junior developers** needing Infrastructure as Code examples
- **Project managers** understanding AWS deployment complexity
- **Organizations** wanting a reference implementation template

## Quick Start

1. Run 00-discovery to configure your project settings
2. Run subsequent stages in order to deploy infrastructure
3. Each stage has `deploy.sh` and `destroy.sh` scripts
4. Scripts are idempotent - safe to run multiple times

## Inter-Stage Data Flow

The deployment pipeline uses a **progressive configuration enhancement pattern**:

### How Stages Connect
1. **Each stage completes** → Creates `output/{project-prefix}-config-{environment}.json`
2. **Next stage starts** → Automatically copies previous stage's output to its `input/` folder
3. **Configuration inheritance** → Environment, region, and all baseline data extracted from input file
4. **Configuration enhancement** → Adds stage-specific data (no re-specification of baseline parameters)
5. **Enhanced output** → Creates new output combining inherited data with new stage-specific resources

### Example Pipeline Flow
```bash
# Stage 00-discovery: Collect ALL baseline parameters
cd iac/00-discovery
./deploy.sh -e DEV -p myapp -i infra -h hosting -d app.dev.example.com --vpc-id vpc-12345
# → Creates: output/myapp-config-dev.json (complete baseline config)

# Stage 01-infra-foundation: Discover/create infrastructure resources (AWS CLI only)
cd ../01-infra-foundation
./deploy.sh
# → Copies: ../00-discovery/output/myapp-config-dev.json → input/myapp-config-dev.json
# → Extracts environment and region from input configuration
# → Uses AWS CLI to discover/create IAM roles and SSL certificates
# → Creates: output/myapp-config-dev.json (enhanced with certificate ARN, role ARNs)

# Stage 02-infra-setup: Configure application infrastructure
cd ../02-infra-setup  
./deploy.sh --cdn-price-class PriceClass_100 --lambda-memory 512
# → Copies: ../01-infra-foundation/output/myapp-config-dev.json → input/myapp-config-dev.json
# → Extracts environment and region from input configuration
# → Uses certificate ARN and VPC from previous stages
# → Creates: output/myapp-config-dev.json (enhanced with app settings)
```

### Flexible Input Sources
Each stage supports custom input via `--input-file`:
```bash
# Use specific output file from previous stage
./deploy.sh --input-file /path/to/myapp-config-dev.json

# Use archived output file from previous stage
./deploy.sh --input-file s3://archive/myapp-config-dev-backup.json
```

## Architecture

```
CloudFront (React SPA) → API Gateway → Lambda (Node.js API)
     ↓
S3 (Static Assets)
```

Domain routing via CloudFront behaviors:
- `/` → React application  
- `/api/*` → Lambda API

## Sample Applications

This monorepo includes four sample applications that demonstrate deployment patterns:

### API Applications (Node.js)
- **placeholder-api** - Initial demo API for infrastructure testing
- **real-api** - Replacement API for production deployment

Both APIs are Node.js applications with identical structure containing two simple handlers:

**Handler 1: Health Check (`/`)**
- Responds to root path with basic health check JSON
- Returns server datetime, success message, and API name
- Differs only in cosmetic text to demonstrate deployment swapping

**Handler 2: Echo Test (`/echo`)**
- Accepts any payload from the React application
- Wraps incoming payload in a response object
- Returns JSON: `{"message": "This is the message I received", "originalMessage": [incoming payload]}`
- Provides simple test functionality for frontend-backend communication

**Deployment:**
- Runs as AWS Lambda functions
- Accessed via CloudFront behaviors at `/api/*` routes
- Demonstrates serverless API architecture

### React Applications (Vite)
- **placeholder-react-app** - Initial demo frontend for infrastructure testing
- **real-react-app** - Replacement frontend for production deployment

Both React apps are built with Vite and functionally identical:

**Core Features:**
- Compiled and served from CloudFront distribution
- Contains a button to test backend communication
- Makes API calls to `/api/echo` endpoint through CloudFront behaviors
- Displays API responses to validate end-to-end connectivity

**Visual Differences:**
- Minor cosmetic differences for deployment distinction
- Same UI layout and functionality
- Both demonstrate successful CloudFront behavior routing

### Purpose
These paired applications demonstrate how to:
1. **Seed environments** initially with placeholder applications
2. **Replace applications** in existing infrastructure without changes
3. **Test deployment patterns** using identical codebases
4. **Validate infrastructure** before deploying business logic

## Project Structure

```
├── packages/           # Sample applications (placeholder + real)
├── iac/               # Infrastructure as Code stages
│   ├── 00-discovery/  # Project configuration (AWS CLI)
│   ├── 01-infra-foundation/  # Infrastructure foundation (AWS CLI)
│   ├── 02-infra-setup/       # Infrastructure setup (Terraform)
│   ├── 03-app-deploy/        # Application deployment (Terraform)
│   └── 04-prod-deploy/       # Production deployment (Terraform)
└── docs/              # Documentation
```

Each stage contains deployment scripts that can be executed in sequence to build the complete infrastructure. Stage 00 and 01 use AWS CLI for resource discovery and creation, while stages 02+ use Terraform for application infrastructure management.