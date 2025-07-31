# Lambda Module Outputs

output "function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.api.function_name
}

output "function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.api.arn
}

output "function_url" {
  description = "Function URL for direct CloudFront integration"
  value       = aws_lambda_function_url.api_url.function_url
}

output "function_url_id" {
  description = "Function URL configuration ID"
  value       = aws_lambda_function_url.api_url.id
}

output "execution_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_execution.arn
}

output "log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.lambda_logs.name
}

output "log_group_arn" {
  description = "ARN of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.lambda_logs.arn
}