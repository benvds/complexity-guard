// Fixture: JavaScript component with JSX
// Expected: Parses as JavaScript, contains JSX elements
import React from 'react';

export function Card({ title, children }) {
  return (
    <div className="card">
      <h2>{title}</h2>
      <div className="card-body">{children}</div>
    </div>
  );
}

export const List = ({ items }) => (
  <ul>
    {items.map((item, i) => (
      <li key={i}>{item}</li>
    ))}
  </ul>
);
