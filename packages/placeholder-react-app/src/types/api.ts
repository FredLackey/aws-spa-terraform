export interface HealthResponse {
  message: string;
  apiName: string;
  timestamp: string;
  status: string;
}

export interface EchoRequest {
  message?: string;
  [key: string]: unknown;
}

export interface EchoResponse {
  message: string;
  originalMessage: EchoRequest;
  apiName: string;
  timestamp: string;
}

export interface ApiError {
  error: string;
  message: string;
  availablePaths?: string[];
}