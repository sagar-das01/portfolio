import React from 'react';
import './Contact.css'; // Will create this later

function Contact() {
  return (
    <section id="contact" className="App-section">
      <h2>Contact Me</h2>
      <p>You can reach me at email@example.com</p>
      {/* Or a simple form placeholder */}
      <form>
        <div>
          <label htmlFor="name">Name:</label>
          <input type="text" id="name" name="name" />
        </div>
        <div>
          <label htmlFor="email">Email:</label>
          <input type="email" id="email" name="email" />
        </div>
        <div>
          <label htmlFor="message">Message:</label>
          <textarea id="message" name="message"></textarea>
        </div>
        <button type="submit">Send</button>
      </form>
    </section>
  );
}

export default Contact;
