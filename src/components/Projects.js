import React from 'react';
import './Projects.css'; // Will create this later

function Projects() {
  return (
    <section id="projects" className="App-section">
      <h2>My Projects</h2>
      {/* Placeholder for project items */}
      <div className="project-item">
        <h3>Project 1</h3>
        <p>Description of project 1.</p>
      </div>
      <div className="project-item">
        <h3>Project 2</h3>
        <p>Description of project 2.</p>
      </div>
    </section>
  );
}

export default Projects;
