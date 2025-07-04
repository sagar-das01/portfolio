import React from 'react';
import { Link } from 'react-router-dom';
import './Header.css'; // Will create this later

function Header() {
  return (
    <header className="App-header">
      <nav>
        <ul>
          <li><Link to="/">Home</Link></li>
          <li><Link to="/about">About</Link></li>
          <li><Link to="/projects">Projects</Link></li>
          <li><Link to="/contact">Contact</Link></li>
        </ul>
      </nav>
    </header>
  );
}

export default Header;
