# Placeholder React App

This is a demonstration React application for AWS SPA Terraform infrastructure testing. It's built with Vite and designed to validate CloudFront distribution and API connectivity.

## Purpose

- **DevOps Infrastructure Testing**: Validates CloudFront behaviors and API routing
- **End-to-End Connectivity**: Tests communication between frontend and Lambda API
- **Deployment Validation**: Confirms successful infrastructure provisioning

## Features

- Health check endpoint testing (`/api/`)
- Echo endpoint testing (`/api/echo`)
- Real-time API response display
- Error handling and loading states
- Responsive design for multiple devices

## Development

### Prerequisites

- Node.js >= 20.0.0
- npm or yarn

### Installation

```bash
npm install
```

### Development Server

```bash
npm run dev
```

Runs the development server on `http://localhost:3000`

### Environment Configuration

Create a `.env` file based on `.env.example`:

```bash
cp .env.example .env
```

Configure the API base URL:

```
VITE_API_BASE_URL=/api
```

### Building for Production

```bash
npm run build
```

The build output will be in the `dist/` directory, ready for deployment to S3/CloudFront.

### Build with Custom API URL

To build with a specific API URL for different environments:

```bash
VITE_API_BASE_URL=https://api.example.com/api npm run build
```

## API Integration

The application expects the following API endpoints:

- `GET /` - Health check endpoint
- `POST /echo` - Echo test endpoint

Both endpoints should return JSON responses and support CORS for browser requests.

## Deployment

This application is designed to be deployed to:

1. **S3 Bucket** - Static assets hosting
2. **CloudFront Distribution** - CDN and routing
3. **API Gateway/Lambda** - Backend API (accessed via `/api/*` behaviors)

The build process creates optimized static assets suitable for S3 hosting and CloudFront distribution.

## Architecture

```
User Browser → CloudFront Distribution
               ├── / (React App from S3)
               └── /api/* (Lambda API)
```

## Scripts

- `npm run dev` - Start development server
- `npm run build` - Build for production
- `npm run preview` - Preview production build locally
- `npm run lint` - Run ESLint