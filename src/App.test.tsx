import { render, screen } from '@testing-library/react';
import '@testing-library/jest-dom';
import App from './App';

test('renders the main application page and header', () => {
  render(<App />);
  const nav = screen.getByRole('navigation');
  const homeLink = screen.getByText(/Home/i);
  expect(homeLink).toBeInTheDocument();
});
