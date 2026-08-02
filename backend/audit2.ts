import { prisma } from './src/lib/prisma.js';
import bcrypt from 'bcryptjs';

async function test() {
  const email = 'test@example.com';
  
  const user = await prisma.user.findFirst({
    where: { email },
    orderBy: { createdAt: 'desc' }
  });
  
  console.log('User found:', user ? user.id : 'NOT FOUND', 'Hash length:', user?.passwordHash?.length);

  // If password comparison is failing for previously existing accounts, maybe bcrypt throws?
  if (user && user.passwordHash) {
    try {
      const match = await bcrypt.compare('Password123!', user.passwordHash);
      console.log('Password123! match:', match);
    } catch (e) {
      console.error('Bcrypt error:', e);
    }
  }
}

test().catch(console.error).finally(() => prisma.$disconnect());
