// Fixture: Complex nested control flow
// Purpose: Stress test for deeply nested conditionals and loops
// Expected complexity: cyclomatic ~12, cognitive ~25, nesting ~4

export function processData(items: any[], config: any): any[] {
  const results: any[] = [];
  for (const item of items) {
    if (item.active) {
      if (item.type === 'premium') {
        if (config.premiumEnabled) {
          for (const sub of item.subscriptions) {
            if (sub.valid && sub.expiresAt > Date.now()) {
              results.push({ ...item, status: 'active-premium' });
            } else if (sub.renewable) {
              results.push({ ...item, status: 'renewable' });
            }
          }
        }
      } else {
        if (item.score > config.threshold || item.override) {
          results.push({ ...item, status: 'qualified' });
        }
      }
    }
  }
  return results;
}
