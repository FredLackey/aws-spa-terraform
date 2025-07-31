# Route 53 DNS Module
# Creates Route 53 A record for custom domain pointing to CloudFront

# Data source to find the hosted zone
data "aws_route53_zone" "main" {
  name         = local.hosted_zone_name
  private_zone = false
}

# A record alias to CloudFront distribution
resource "aws_route53_record" "main" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.domain
  type    = "A"
  
  alias {
    name                   = var.cloudfront_domain_name
    zone_id                = var.cloudfront_hosted_zone_id
    evaluate_target_health = false
  }
  
  depends_on = [data.aws_route53_zone.main]
}

# AAAA record alias to CloudFront distribution (IPv6 support)
resource "aws_route53_record" "ipv6" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.domain
  type    = "AAAA"
  
  alias {
    name                   = var.cloudfront_domain_name
    zone_id                = var.cloudfront_hosted_zone_id
    evaluate_target_health = false
  }
  
  depends_on = [data.aws_route53_zone.main]
}