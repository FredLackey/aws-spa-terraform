import { ApiTester } from './components/ApiTester';
import './App.css';

function App() {
  return (
    <div className="App">
      <header className="App-header">
        <h1>🏗️ Placeholder React App</h1>
        <p>
          This is a demonstration React application for AWS SPA Terraform infrastructure testing.
        </p>
        <p className="app-info">
          <strong>Purpose:</strong> DevOps team infrastructure validation and CloudFront behavior testing
        </p>
      </header>

      <main className="App-main">
        <ApiTester title="API Connection Test" />
        
        <div className="info-section">
          <h3>About This Application</h3>
          <ul>
            <li>Built with React + Vite for optimal performance</li>
            <li>Configured for CloudFront distribution deployment</li>
            <li>Tests API connectivity through CloudFront behaviors</li>
            <li>Validates end-to-end infrastructure setup</li>
          </ul>
        </div>
      </main>

      <footer className="App-footer">
        <p>AWS SPA Terraform Monorepo - Placeholder Application</p>
      </footer>
    </div>
  );
}

export default App;