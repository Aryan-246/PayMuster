import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '../../generated/prisma/client.js';
import { config } from './config.js';
const globalForPrisma = globalThis;
const adapter = new PrismaPg({ connectionString: config.databaseUrl });
export const prisma = globalForPrisma.prisma ?? new PrismaClient({ adapter });
if (process.env.NODE_ENV !== 'production') {
    globalForPrisma.prisma = prisma;
}
