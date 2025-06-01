import React from 'react';
import { BrowserRouter as Router, Routes, Route, Link } from 'react-router-dom';
import logo from './logo.svg';
import './App.css';
import { BrowserRouter as Router, Route, Routes } from 'react-router-dom';
import Header from './components/Header';
import Home from './components/Home';
import About from './components/About';
import Projects from './components/Projects';
import Contact from './components/Contact';
import Footer from './components/Footer';

function App() {
  return (
    <Router>
      <div className="App">
        <header className="App-header">
          <img src={logo} className="App-logo" alt="logo" />
          <nav className="mt-3 mb-3">
            <Link to="/" className="App-link" style={{ marginRight: '15px' }}>Home</Link>
            <Link to="/projects" className="App-link">Projects</Link>
          </nav>
          <p>
            {/* Edit <code>src/App.js</code> and save to reload. (This line can be removed or kept) */}
          </p>
          <a
            className="App-link"
            href="https://reactjs.org"
            target="_blank"
            rel="noopener noreferrer"
            style={{ marginTop: '10px' }}
          >
            Learn React
          </a>
        </header>
        <main>
          <Routes>
            <Route path="/projects" element={<Projects />} />
            <Route path="/" element={
              <div className="container mt-5">
                <h1 className="text-center">Welcome to Our Page!</h1>
                <p className="text-center">This is the home page. Click on 'Projects' to see our work.</p>
              </div>
            } />
          </Routes>
        </main>
        <Footer />
      </div>
    </Router>
  );
}

export default App;
