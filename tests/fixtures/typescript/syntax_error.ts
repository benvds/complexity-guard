// Fixture: TypeScript with syntax errors
// Expected: Tree-sitter produces tree with ERROR nodes but still parseable
// Used to verify graceful error handling (PARSE-05)

export function validFunction(x: number): number {
  return x * 2;
}

// Intentional syntax error: missing closing brace
export function brokenFunction(y: string) {
  if (y.length > 0) {
    console.log(y);
  // missing closing brace for function

export function anotherValidFunction(): void {
  console.log("still valid");
}
