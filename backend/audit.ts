import { prisma } from './src/lib/prisma.js';
import dotenv from 'dotenv';

dotenv.config(); // Ensure .env is loaded


async function audit() {
  console.log('--- AUDIT REPORT ---');
  console.log('DATABASE_URL:', process.env.DATABASE_URL);
  
  const users = await prisma.user.findMany({
    select: {
      id: true,
      email: true,
      passwordHash: true,
      createdAt: true
    }
  });

  console.log(`\nFound ${users.length} users:`);
  users.forEach(u => {
    console.log(`ID: ${u.id}, Email: ${u.email}, HashLen: ${u.passwordHash ? u.passwordHash.length : 0}, Created: ${u.createdAt.toISOString()}`);
  });
}

audit().catch(console.error).finally(() => prisma.$disconnect());
