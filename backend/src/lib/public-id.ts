import crypto from 'node:crypto';
import { prisma } from './prisma.js';

function generateRandomPublicId(prefix: string): string {
  const randomNum = Math.floor(100000 + Math.random() * 900000);
  return `${prefix}-${randomNum}`;
}

export async function allocateNextPublicId(prefix: string, entityType: string): Promise<string> {
  try {
    const seq = await prisma.publicIdSequence.upsert({
      where: {
        entityType_prefix: {
          entityType,
          prefix,
        },
      },
      update: {
        counter: { increment: 1 },
      },
      create: {
        entityType,
        prefix,
        counter: 1,
      },
    });
    const formattedCounter = String(seq.counter).padStart(6, '0');
    const candidateId = `${prefix}-${formattedCounter}`;

    if (entityType === 'Organization') {
      const existing = await prisma.organization.findFirst({ where: { publicId: candidateId } });
      if (existing) {
        return `${prefix}-${formattedCounter}-${Math.floor(100 + Math.random() * 900)}`;
      }
    } else if (entityType === 'User') {
      const existing = await prisma.user.findFirst({ where: { publicId: candidateId } });
      if (existing) {
        return `${prefix}-${formattedCounter}-${Math.floor(100 + Math.random() * 900)}`;
      }
    } else if (entityType === 'OwnerRequest') {
      const existing = await prisma.ownerRequest.findFirst({ where: { publicId: candidateId } });
      if (existing) {
        return `${prefix}-${formattedCounter}-${Math.floor(100 + Math.random() * 900)}`;
      }
    }

    return candidateId;
  } catch {
    return generateRandomPublicId(prefix);
  }
}


export function allocateUserPublicId(): string {
  return generateRandomPublicId('PM-USR');
}

export function allocateCompanyPublicId(): string {
  return generateRandomPublicId('PM-CMP');
}

export function allocateOwnerRequestPublicId(): string {
  return generateRandomPublicId('PM-OWN');
}

export function allocateSitePublicId(): string {
  return generateRandomPublicId('PM-SIT');
}

export function allocateAttendancePublicId(): string {
  return generateRandomPublicId('PM-ATT');
}

export function allocatePayrollPublicId(): string {
  return generateRandomPublicId('PM-PAY');
}

export function allocateDocumentPublicId(): string {
  return generateRandomPublicId('PM-DOC');
}

