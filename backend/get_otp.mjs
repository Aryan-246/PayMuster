import { PrismaClient } from './generated/prisma/index.js';
const prisma = new PrismaClient();

async function main() {
  const otp = await prisma.authOtp.findFirst({
    where: { email: 'paymuster.auth+test1@gmail.com' }
  });
  console.log(JSON.stringify(otp, null, 2));
}

main().finally(() => prisma.$disconnect());
