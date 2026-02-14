// Fixture: Class with multiple methods
// Purpose: Test function detection in class contexts (constructors, methods, private methods)
// Expected complexity: findById ~3, updateEmail ~4, isValidEmail ~1

export class UserService {
  private users: Map<string, User> = new Map();

  constructor(private readonly db: Database) {}

  async findById(id: string): Promise<User | null> {
    const cached = this.users.get(id);
    if (cached) {
      return cached;
    }
    const user = await this.db.query('SELECT * FROM users WHERE id = ?', [id]);
    if (user) {
      this.users.set(id, user);
    }
    return user ?? null;
  }

  async updateEmail(id: string, email: string): Promise<boolean> {
    const user = await this.findById(id);
    if (!user) {
      throw new Error(`User ${id} not found`);
    }
    if (!this.isValidEmail(email)) {
      throw new Error('Invalid email format');
    }
    user.email = email;
    await this.db.update('users', { id }, { email });
    return true;
  }

  private isValidEmail(email: string): boolean {
    return email.includes('@') && email.includes('.');
  }
}

interface User {
  id: string;
  email: string;
  name: string;
}

interface Database {
  query(sql: string, params: any[]): Promise<any>;
  update(table: string, where: any, data: any): Promise<void>;
}
