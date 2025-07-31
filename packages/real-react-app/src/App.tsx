import { ApiTester } from './components/ApiTester';
import './App.css';

function App() {
  return (
    <div className="App">
      <header className="App-header">
        <h1>🚀 Real React App</h1>
        <p>
          This is the production React application for AWS SPA Terraform business logic implementation.
        </p>
        <p className="app-info">
          <strong>Purpose:</strong> Developer community application deployment and business logic execution
        </p>
      </header>

      <main className="App-main">
        <ApiTester title="API Connection Test" />
        
        <div className="info-section">
          <h3>About This Application</h3>
          <ul>
            <li>Production-ready React + Vite application</li>
            <li>Optimized for CloudFront global distribution</li>
            <li>Demonstrates real-world API integration patterns</li>
            <li>Ready for business logic implementation</li>
          </ul>
        </div>
      </main>

      <footer className="App-footer">
        <p>AWS SPA Terraform Monorepo - Production Application</p>
      </footer>
    </div>
  );
}

export default App;