import { render, screen } from '@testing-library/react';
import App from './App';

import { within } from '@testing-library/react';

test('renders the main application page and header', () => {
  render(<App />);
  // Check if the Header component's navigation is rendered
  // First, get the navigation landmark
  const nav = screen.getByRole('navigation');
  // Then, query for the "Home" link within the navigation
  const homeLink = within(nav).getByText(/Home/i);
  expect(homeLink).toBeInTheDocument();

  // You could also check for a more generic part of App.js
  // For example, if you have a main role in App.js
  // const mainElement = screen.getByRole('main');
  // expect(mainElement).toBeInTheDocument();
});
