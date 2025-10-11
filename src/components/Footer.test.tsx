import { render, screen } from '@testing-library/react';
import Footer from './Footer';

test('renders Footer with copyright text', () => {
  render(<Footer />);
  const copyrightText = screen.getByText(/Your Name. All rights reserved./i); // Adjust "Your Name" if you changed it in Footer.js
  expect(copyrightText).toBeInTheDocument();
});
