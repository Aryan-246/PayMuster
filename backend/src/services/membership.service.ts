import { prisma } from '../lib/prisma.js';
import { featureFlags } from '../lib/feature-flags.js';

/**
 * Cross-company membership reads (blueprint §L). Everything here is dormant
 * while MULTI_COMPANY_ENABLED is OFF: the switchable-companies list is empty
 * and callers render no company-switching UI. The primary organization always
 * comes from user.orgId — membership rows never move it.
 */
export class MembershipService {
  /**
   * The companies a user may operate in: their primary org (always) plus
   * ACTIVE memberships (only when the multi-company flag is ON).
   * INVITED / SUSPENDED / REMOVED memberships are never switchable.
   */
  async listUserCompanies(userId: string): Promise<{
    multiCompanyEnabled: boolean;
    primary: { orgId: string; name: string; publicId: string | null } | null;
    memberships: Array<{
      orgId: string;
      name: string;
      publicId: string | null;
      role: string;
      status: string;
    }>;
  }> {
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: {
        orgId: true,
        org: { select: { id: true, name: true, publicId: true } },
      },
    });

    const primary = user?.org
      ? { orgId: user.org.id, name: user.org.name, publicId: user.org.publicId }
      : null;

    if (!featureFlags.multiCompanyEnabled) {
      // Flag OFF: dormant. Honest empty list — no membership rows are read.
      return { multiCompanyEnabled: false, primary, memberships: [] };
    }

    const rows = await prisma.membership.findMany({
      where: { userId, status: 'ACTIVE' },
      select: {
        orgId: true,
        role: true,
        status: true,
        org: { select: { id: true, name: true, publicId: true } },
      },
      orderBy: { createdAt: 'asc' },
    });

    const memberships = rows
      // Defensive: never offer the primary org as a "switch" target.
      .filter((row) => row.org && row.org.id !== user?.orgId)
      .map((row) => ({
        orgId: row.org.id,
        name: row.org.name,
        publicId: row.org.publicId,
        role: row.role,
        status: row.status,
      }));

    return { multiCompanyEnabled: true, primary, memberships };
  }
}

export const membershipService = new MembershipService();
