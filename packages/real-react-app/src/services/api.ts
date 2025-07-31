import { HealthResponse, EchoRequest, EchoResponse } from '../types/api';

class ApiClient {
  private baseUrl: string;

  constructor() {
    this.baseUrl = import.meta.env.VITE_API_BASE_URL || '/api';
    console.log('API Base URL:', this.baseUrl);
  }

  private async makeRequest<T>(
    endpoint: string,
    options: RequestInit = {}
  ): Promise<T> {
    const url = `${this.baseUrl}${endpoint}`;
    
    const defaultHeaders = {
      'Content-Type': 'application/json',
    };

    const config: RequestInit = {
      ...options,
      headers: {
        ...defaultHeaders,
        ...options.headers,
      },
    };

    try {
      const response = await fetch(url, config);
      
      if (!response.ok) {
        const errorData = await response.json().catch(() => ({
          error: 'HTTP Error',
          message: `Request failed with status ${response.status}`,
        }));
        throw new Error(`API Error: ${errorData.message || response.statusText}`);
      }

      return await response.json();
    } catch (error) {
      if (error instanceof Error) {
        throw error;
      }
      throw new Error('An unknown error occurred');
    }
  }

  async healthCheck(): Promise<HealthResponse> {
    return this.makeRequest<HealthResponse>('/');
  }

  async echo(payload: EchoRequest): Promise<EchoResponse> {
    return this.makeRequest<EchoResponse>('/echo', {
      method: 'POST',
      body: JSON.stringify(payload),
    });
  }
}

export const apiClient = new ApiClient();