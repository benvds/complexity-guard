// Fixture: Async/await patterns with error handling
// Purpose: Test detection of promise chains, async/await, try/catch, and optional chaining
// Expected complexity: cyclomatic ~5, cognitive ~8, nesting ~2

export async function fetchUserData(
  userId: string,
  options: { includeProfile?: boolean; includeOrders?: boolean } = {}
): Promise<{ user: any; profile?: any; orders?: any[] }> {
  const user = await fetch(`/api/users/${userId}`).then(r => {
    if (!r.ok) {
      throw new Error(`Failed to fetch user: ${r.status}`);
    }
    return r.json();
  });

  const result: { user: any; profile?: any; orders?: any[] } = { user };

  if (options.includeProfile) {
    try {
      result.profile = await fetch(`/api/users/${userId}/profile`).then(r => r.json());
    } catch (err) {
      console.warn('Failed to fetch profile:', err);
      result.profile = null;
    }
  }

  if (options.includeOrders) {
    const orders = await fetch(`/api/users/${userId}/orders`)
      .then(r => r.json())
      .then((data: any[]) => data.filter(o => o.status !== 'cancelled'))
      .catch(() => []);
    result.orders = orders;
  }

  return result;
}
