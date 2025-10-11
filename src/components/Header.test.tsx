import { render, screen } from '@testing-library/react';
import { BrowserRouter as Router } from 'react-router-dom'; // Header uses <Link>
import Header from './Header';

test('renders Header with navigation links', () => {
  render(
    <Router> {/* Wrap Header with Router because it contains Link components */}
      <Header />
    </Router>
  );

  // Check for presence of navigation links
  expect(screen.getByText(/Home/i)).toBeInTheDocument();
  expect(screen.getByText(/About/i)).toBeInTheDocument();
  expect(screen.getByText(/Projects/i)).toBeInTheDocument();
  expect(screen.getByText(/Contact/i)).toBeInTheDocument();
});
