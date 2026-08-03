import { prisma } from '../src/lib/prisma.ts';
import bcrypt from 'bcryptjs';

// Load .env automatically if it's there
import 'dotenv/config';

async function hashPassword(password: string): Promise<string> {
  const salt = await bcrypt.genSalt(10);
  return bcrypt.hash(password, salt);
}

async function main() {
  const email = process.env.SUPER_ADMIN_EMAIL;
  const password = process.env.SUPER_ADMIN_PASSWORD;

  if (!email || !password) {
    console.log('Skipping super admin seed. SUPER_ADMIN_EMAIL or SUPER_ADMIN_PASSWORD not set in .env');
    return;
  }

  const existing = await prisma.user.findFirst({
    where: { email },
  });

  if (!existing) {
    const passwordHash = await hashPassword(password);
    await prisma.user.create({
      data: {
        email,
        passwordHash,
        role: 'SUPER_ADMIN',
        status: 'VERIFIED',
        emailVerified: true,
        firstName: 'Super',
        lastName: 'Admin',
      },
    });
    console.log('Super Admin seeded successfully.');
  } else {
    // Optionally update the existing super admin to ensure correct role and status
    await prisma.user.update({
      where: { id: existing.id },
      data: {
        role: 'SUPER_ADMIN',
        status: 'VERIFIED',
      },
    });
    console.log('Super Admin already exists. Updated role and status.');
  }
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
