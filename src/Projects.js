import React from 'react';
import ProjectCard from './ProjectCard';
import projectsData from './projects.json';

const Projects = () => {
  // Slice the array to get only the first 4 projects
  const displayedProjects = projectsData.slice(0, 4);

  return (
    <div className="container mt-5">
      {/* Updated this line */}
      <h2 className="mb-4 projects-title">Our Projects</h2>
      <div className="row">
        {displayedProjects.map(project => (
          <ProjectCard key={project.id} project={project} />
        ))}
      </div>
    </div>
  );
};

export default Projects;
