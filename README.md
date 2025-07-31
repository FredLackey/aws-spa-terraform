# AWS SPA Terraform Monorepo

## What This Is

A **demonstration template** showing how to deploy a Single Page Application (SPA) to AWS using a structured, multi-stage approach. This repo provides a complete example of Infrastructure as Code (IaC) deployment using Terraform and AWS CLI automation.

## Key Features

- **Multi-stage deployment** - Organized stages from initial setup to production deployment
- **CloudFront + Lambda architecture** - React frontend via CloudFront CDN, Node.js API via Lambda
- **Cross-account AWS setup** - Demonstrates infrastructure and hosting account separation
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
│   ├── 00-discovery/  # Project configuration
│   ├── 01-infra-foundation/  # Infrastructure foundation
│   ├── 02-infra-setup/       # Infrastructure setup
│   ├── 03-app-deploy/        # Application deployment
│   └── 04-prod-deploy/       # Production deployment
└── docs/              # Documentation
```

Each stage contains independent Terraform configurations and deployment scripts that can be executed in sequence to build the complete infrastructure.