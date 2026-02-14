// Fixture: React component with JSX (TSX)
// Expected: Parses as TSX, contains function and JSX elements
import React from 'react';

interface Props {
  name: string;
  count: number;
}

export function Greeting({ name, count }: Props): JSX.Element {
  if (count > 10) {
    return <div className="warning">Too many: {count}</div>;
  }
  return (
    <div className="greeting">
      <h1>Hello, {name}!</h1>
      <p>Count: {count}</p>
    </div>
  );
}

export const Badge: React.FC<{ label: string }> = ({ label }) => (
  <span className="badge">{label}</span>
);
