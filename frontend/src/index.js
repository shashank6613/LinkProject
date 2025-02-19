import React from 'react';
import ReactDOM from 'react-dom';
import './index.css'; // Optional: Custom CSS for app-wide styling
import App from './App'; // Main App component
import { BrowserRouter as Router } from 'react-router-dom'; // Importing Router for routing

// Rendering the app inside the root div
ReactDOM.render(
  <Router>
    <App />
  </Router>,
  document.getElementById('root')
);
