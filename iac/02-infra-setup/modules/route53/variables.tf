# Route 53 Module Variables

variable "domain" {
  description = "Full domain name for the A record"
  type        = string
}

variable "hosted_zone_name" {
  description = "Name of the hosted zone (derived from domain)"
  type        = string
  default     = ""
}

variable "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  type        = string
}

variable "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  type        = string
}

variable "cloudfront_hosted_zone_id" {
  description = "CloudFront distribution hosted zone ID"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Local to extract hosted zone from domain
locals {
  # Extract hosted zone from domain (e.g., "app.example.com" -> "example.com")
  hosted_zone_name = var.hosted_zone_name != "" ? var.hosted_zone_name : join(".", slice(split(".", var.domain), 1, length(split(".", var.domain))))
}