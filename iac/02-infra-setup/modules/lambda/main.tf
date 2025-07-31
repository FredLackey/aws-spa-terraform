# Lambda Function Module
# Creates Lambda function with Function URLs for direct CloudFront integration

# IAM role for Lambda execution
resource "aws_iam_role" "lambda_execution" {
  name = "${var.project_prefix}-${var.environment}-lambda-execution-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
  
  tags = var.tags
}

# Attach basic Lambda execution policy
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_execution.name
}

# Attach VPC access policy if VPC is specified
resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  count      = var.vpc_id != "" ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
  role       = aws_iam_role.lambda_execution.name
}

# Lambda function
resource "aws_lambda_function" "api" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "${var.project_prefix}-${var.environment}-api"
  role            = aws_iam_role.lambda_execution.arn
  handler         = "index.handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime         = "nodejs20.x"
  memory_size     = var.memory_size
  timeout         = var.timeout
  
  # VPC configuration (optional)
  dynamic "vpc_config" {
    for_each = var.vpc_id != "" ? [1] : []
    content {
      subnet_ids         = var.subnet_ids
      security_group_ids = var.security_group_ids
    }
  }
  
  environment {
    variables = {
      NODE_ENV = var.environment
      PROJECT  = var.project_prefix
    }
  }
  
  tags = var.tags
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.api.function_name}"
  retention_in_days = var.log_retention_days
  
  tags = var.tags
}

# Lambda Function URL
resource "aws_lambda_function_url" "api_url" {
  function_name      = aws_lambda_function.api.function_name
  authorization_type = "NONE"
  
  cors {
    allow_credentials = false
    allow_origins     = ["*"]
    allow_methods     = ["*"]
    allow_headers     = ["*"]
    expose_headers    = ["*"]
    max_age          = 86400
  }
}

# Create placeholder API code
resource "local_file" "lambda_code" {
  filename = "${path.module}/lambda_code/index.js"
  content = templatefile("${path.module}/lambda_code_template.js", {
    project_prefix = var.project_prefix
    environment    = var.environment
  })
  
  depends_on = [null_resource.ensure_lambda_dir]
}

# Ensure lambda_code directory exists
resource "null_resource" "ensure_lambda_dir" {
  provisioner "local-exec" {
    command = "mkdir -p ${path.module}/lambda_code"
  }
}

# Create ZIP archive of Lambda code
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_code"
  output_path = "${path.module}/lambda_code.zip"
  
  depends_on = [local_file.lambda_code]
}