import { useState } from 'react';
import { apiClient } from '../services/api';
import { HealthResponse, EchoResponse } from '../types/api';

interface ApiTesterProps {
  title: string;
}

export const ApiTester = ({ title }: ApiTesterProps) => {
  const [healthData, setHealthData] = useState<HealthResponse | null>(null);
  const [echoData, setEchoData] = useState<EchoResponse | null>(null);
  const [echoInput, setEchoInput] = useState('Hello from Placeholder React App!');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleHealthCheck = async () => {
    setLoading(true);
    setError(null);
    try {
      const response = await apiClient.healthCheck();
      setHealthData(response);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Health check failed');
    } finally {
      setLoading(false);
    }
  };

  const handleEchoTest = async () => {
    setLoading(true);
    setError(null);
    try {
      const response = await apiClient.echo({ message: echoInput });
      setEchoData(response);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Echo test failed');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="api-tester">
      <h2>{title}</h2>
      
      <div className="test-section">
        <h3>Health Check Test</h3>
        <button onClick={handleHealthCheck} disabled={loading}>
          {loading ? 'Testing...' : 'Test Health Check'}
        </button>
        
        {healthData && (
          <div className="response-display">
            <h4>Health Check Response:</h4>
            <pre>{JSON.stringify(healthData, null, 2)}</pre>
          </div>
        )}
      </div>

      <div className="test-section">
        <h3>Echo Test</h3>
        <div className="input-group">
          <label htmlFor="echo-input">Message to echo:</label>
          <input
            id="echo-input"
            type="text"
            value={echoInput}
            onChange={(e) => setEchoInput(e.target.value)}
            placeholder="Enter message to echo..."
          />
        </div>
        <button onClick={handleEchoTest} disabled={loading}>
          {loading ? 'Testing...' : 'Test Echo Endpoint'}
        </button>
        
        {echoData && (
          <div className="response-display">
            <h4>Echo Response:</h4>
            <pre>{JSON.stringify(echoData, null, 2)}</pre>
          </div>
        )}
      </div>

      {error && (
        <div className="error-display">
          <h4>Error:</h4>
          <p>{error}</p>
        </div>
      )}
    </div>
  );
};