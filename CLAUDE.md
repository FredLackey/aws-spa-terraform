# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This monorepo is a **demonstration template** showing how to deploy Single Page Applications (SPAs) to AWS using Infrastructure as Code. It is NOT a production application but rather a reference implementation for deployment patterns.

## Architecture Overview

### Multi-Stage Deployment Pattern
The repository uses a structured, sequential deployment approach with numbered stages:

- **00-discovery** - Project configuration initialization and domain setup
- **01-infra-foundation** - AWS account setup, cross-account trust relationships, Route 53
- **02-infra-setup** - Infrastructure automation, SSL certificates, placeholder application deployment
- **03-app-deploy** - Development environment provisioning and deployment script testing
- **04-prod-deploy** - Production deployment with real applications

Each stage contains:
- `deploy.sh` and `destroy.sh` scripts (standardized entry points)
- `terraform/` directory for Infrastructure as Code
- `input/` and `output/` directories for inter-stage data flow
- Independent Terraform state management

### Sample Applications Architecture
Four demonstration applications prove the deployment patterns work:

**API Applications (Node.js → AWS Lambda):**
- `placeholder-api` and `real-api` are nearly identical codebases
- Two handlers: health check (`/`) and echo test (`/echo`)
- Deployed as Lambda functions, accessed via CloudFront `/api/*` behaviors

**Frontend Applications (React/Vite → CloudFront):**
- `placeholder-react-app` and `real-react-app` are functionally identical
- Built with Vite, served from CloudFront distribution
- Contains test button that calls `/api/echo` to validate end-to-end connectivity
- Minor cosmetic differences to demonstrate deployment swapping

### Data Flow Pattern
All inter-stage communication uses JSON format:
- Previous stage outputs stored in `output/` folder
- Next stage consumes data from `input/` folder
- Ensures consistent parsing across all deployment stages

### AWS Multi-Account Strategy
- **Infrastructure Account** - Shared services, monitoring, security resources
- **Hosting Account** - Application-specific resources and environments
- Cross-account IAM trust relationships managed in stage 01-infra-foundation

## Key Design Principles

### State-Aware Execution
All scripts check resource existence before attempting operations:
- Terraform manages infrastructure state automatically
- Bash scripts use AWS CLI to verify prerequisites
- Scripts are idempotent and safe to re-run multiple times

### Standardized Entry Points
- Only `deploy.sh` and `destroy.sh` serve as human entry points
- No alternative names like `bootstrap.sh`, `init.sh`, or `configure.sh`
- All scripts support standardized arguments: `--environment/-e`, `--region/-r`, `--remove-tf/-t`

### Environment Standards
Environment codes: `SBX` (Sandbox), `DEV` (Development), `TEST`, `UAT` (User Acceptance Testing), `STAGE` (Staging), `MO` (Model Office), `PROD` (Production)

### Directory Structure Standards
All AWS resources and local directories follow: `{project-prefix}/{environment}` hierarchy

### AWS Resource Tagging
Mandatory tags on all resources: `Project` (project prefix), `Environment` (dev/staging/prod)

## Script Execution Patterns

### deploy.sh Standard Flow
1. Authentication validation (AWS SSO required)
2. Stage state evaluation (skip if already deployed)
3. Input data preparation (copy from previous stage output)
4. Infrastructure deployment (Terraform + additional scripts)
5. Output generation (for next stage consumption)

### destroy.sh Standard Flow
1. Authentication validation
2. Stage state evaluation (skip if already destroyed)
3. Dependency validation (warn of downstream impacts)
4. Infrastructure destruction (reverse dependency order)
5. Terraform state management (preserve by default, remove with `--remove-tf`)

## User Personas and Ownership

- **AWS Cloud Owner** - Stages 00-discovery, 01-infra-foundation (account governance, DNS, certificates)
- **DevOps Team** - Stages 02-infra-setup, 03-app-deploy (infrastructure automation, CI/CD)
- **Developer Community** - Stage 04-prod-deploy (application development, business logic)

## What This Repository Does NOT Include

- CI/CD pipelines or automated workflows
- Secrets management systems
- Production business logic
- Comprehensive monitoring/alerting
- Security scanning or compliance frameworks
- Database design or data modeling
- Authentication systems beyond basic AWS setup

## Terraform Backend Standards

Each stage uses dedicated S3 + DynamoDB backends:
- S3 Bucket: `terraform-state-{account-id}-{stage}-{environment}`
- DynamoDB Table: `terraform-locks-{account-id}-{stage}-{environment}`
- State files organized by stage and environment paths