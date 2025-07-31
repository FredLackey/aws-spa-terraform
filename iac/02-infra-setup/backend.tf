# Stage 02 Infrastructure Setup - Terraform Backend Configuration
# S3 backend with DynamoDB state locking and KMS encryption

terraform {
  backend "s3" {
    # Backend configuration will be provided via backend config file or command line
    # This ensures proper isolation between environments and stages
    
    # The following values will be dynamically configured:
    # bucket         = "terraform-state-{project-prefix}-{environment}-infra"
    # key            = "{project-prefix}/{environment}/02-infra-setup/terraform.tfstate"
    # region         = "{region}"
    # dynamodb_table = "terraform-locks-{project-prefix}-{environment}-infra"
    # encrypt        = true
    # kms_key_id     = "alias/terraform-state-key"
  }
  
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Provider configuration for infrastructure account
provider "aws" {
  alias  = "infrastructure"
  region = var.region
  
  # Use infrastructure profile for backend and cross-account resources
  profile = var.infrastructure_profile
  
  default_tags {
    tags = {
      Project     = var.project_prefix
      Environment = var.environment
      Stage       = "02-infra-setup"
      ManagedBy   = "terraform"
    }
  }
}

# Provider configuration for hosting account (where resources will be created)
provider "aws" {
  alias  = "hosting"
  region = var.region
  
  # Assume cross-account role in hosting account
  assume_role {
    role_arn = var.cross_account_role_arn
  }
  
  default_tags {
    tags = {
      Project     = var.project_prefix
      Environment = var.environment
      Stage       = "02-infra-setup"
      ManagedBy   = "terraform"
    }
  }
}