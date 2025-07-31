# Lambda Module Variables

variable "project_prefix" {
  description = "Project prefix for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod, etc.)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for Lambda functions (optional)"
  type        = string
  default     = ""
}

variable "subnet_ids" {
  description = "Subnet IDs for Lambda VPC configuration"
  type        = list(string)
  default     = []
}

variable "security_group_ids" {
  description = "Security group IDs for Lambda VPC configuration"
  type        = list(string)
  default     = []
}

variable "memory_size" {
  description = "Memory allocation for Lambda function in MB"
  type        = number
  default     = 128
  
  validation {
    condition     = var.memory_size >= 128 && var.memory_size <= 10240
    error_message = "Lambda memory must be between 128 and 10240 MB."
  }
}

variable "timeout" {
  description = "Timeout for Lambda function in seconds"
  type        = number
  default     = 15
  
  validation {
    condition     = var.timeout >= 1 && var.timeout <= 900
    error_message = "Lambda timeout must be between 1 and 900 seconds."
  }
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 14
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}