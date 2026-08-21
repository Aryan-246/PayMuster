import { AppError } from './app-error.js';
import { prisma } from './prisma.js';
import { logger } from './logger.js';

class MaintenanceService {
  private isMaintenanceMode: boolean = false;
  private lastFetched: number = 0;
  private readonly CACHE_TTL = 30000; // 30 seconds

  async getIsMaintenanceMode(): Promise<boolean> {
    const now = Date.now();
    if (now - this.lastFetched < this.CACHE_TTL) {
      return this.isMaintenanceMode;
    }

    try {
      const setting = await prisma.systemSettings.findUnique({
        where: { key: 'MAINTENANCE_MODE' }
      });
      this.isMaintenanceMode = setting?.value === 'true';
      this.lastFetched = now;
      return this.isMaintenanceMode;
    } catch (error) {
      logger.error('maintenance.state_fetch_failed', error);
      throw new AppError(
        'MAINTENANCE_STATE_UNKNOWN',
        'PayMuster availability could not be verified.',
        503,
      );
    }
  }

  async assertOperational(role?: string): Promise<void> {
    let isMaintenance = true;
    try {
      isMaintenance = await this.getIsMaintenanceMode();
    } catch (error) {
      if (role === 'SUPER_ADMIN') {
        logger.warn('maintenance.state_unknown_super_admin_allowed');
        return;
      }
      throw error;
    }

    if (isMaintenance && role !== 'SUPER_ADMIN') {
      throw new AppError(
        'MAINTENANCE_MODE',
        'PayMuster is temporarily unavailable for maintenance.',
        503,
      );
    }
  }

  async setMaintenanceMode(enabled: boolean, updatedBy: string): Promise<void> {
    await prisma.$transaction(async (tx) => {
      await tx.systemSettings.upsert({
        where: { key: 'MAINTENANCE_MODE' },
        update: {
          value: enabled ? 'true' : 'false',
          updatedBy
        },
        create: {
          key: 'MAINTENANCE_MODE',
          value: enabled ? 'true' : 'false',
          updatedBy
        }
      });
      await tx.auditLog.create({
        data: {
          action: 'UPDATE',
          entityType: 'SystemSettings',
          entityId: '00000000-0000-0000-0000-000000000000',
          changes: { key: 'MAINTENANCE_MODE', enabled },
          userId: updatedBy
        }
      });
    });
    this.isMaintenanceMode = enabled;
    this.lastFetched = Date.now();
  }
}

export const maintenanceService = new MaintenanceService();
