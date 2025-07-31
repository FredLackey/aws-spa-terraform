# Real API

A demonstration Node.js API designed for AWS Lambda deployment as part of the AWS SPA Terraform monorepo production deployment.

## Purpose

This API serves as the production replacement application that demonstrates how to swap applications in existing infrastructure without requiring infrastructure changes. It is functionally identical to the placeholder-api with only cosmetic differences in response messages.

## Endpoints

### Health Check - `GET/POST /`
Returns basic health status information:
```json
{
  "message": "Real API is running successfully",
  "apiName": "real-api",
  "timestamp": "2024-01-01T00:00:00.000Z",
  "status": "healthy"
}
```

### Echo Test - `POST /echo`
Accepts any JSON payload and returns it wrapped in a response object:
```json
{
  "message": "This is the message I received",
  "originalMessage": { /* your input payload */ },
  "apiName": "real-api",
  "timestamp": "2024-01-01T00:00:00.000Z"
}
```

## Features

- AWS Lambda compatible handler
- CORS headers for CloudFront integration
- Basic error handling and validation
- JSON response formatting
- Support for API Gateway event structure

## Deployment

This API is designed to be deployed as an AWS Lambda function and accessed through CloudFront behaviors at `/api/*` routes. It replaces the placeholder-api during the production deployment stage to demonstrate seamless application swapping.

## Testing

Testing will occur as part of the infrastructure deployment validation process. The echo endpoint enables end-to-end connectivity testing between the React frontend and the Lambda backend through CloudFront.