# Route 53 Module Outputs

output "record_name" {
  description = "Name of the Route 53 record"
  value       = aws_route53_record.main.name
}

output "record_fqdn" {
  description = "FQDN of the Route 53 record"
  value       = aws_route53_record.main.fqdn
}

output "record_type" {
  description = "Type of the Route 53 record"
  value       = aws_route53_record.main.type
}

output "hosted_zone_id" {
  description = "ID of the hosted zone"
  value       = data.aws_route53_zone.main.zone_id
}

output "hosted_zone_name" {
  description = "Name of the hosted zone"
  value       = data.aws_route53_zone.main.name
}