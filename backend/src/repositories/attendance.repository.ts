import { prisma } from '../lib/prisma.js';
import {
  AttendanceStatus,
  ShiftType,
  SiteStatus,
  StaffStatus,
} from '../../generated/prisma/index.js';
import { StoredCoordinateMapsProvider } from '../providers/maps.provider.js';
import { AppError } from '../lib/app-error.js';

const attendanceInclude = {
  staff: {
    select: {
      id: true,
      publicId: true,
      firstName: true,
      lastName: true,
      workerType: true,
      status: true,
    },
  },
  site: { select: { id: true, publicId: true, name: true } },
  markedBy: { select: { id: true, firstName: true, lastName: true } },
};

function startUtcDay(date: Date): Date {
  return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
}

function nextUtcDay(date: Date): Date {
  const nextDay = startUtcDay(date);
  nextDay.setUTCDate(nextDay.getUTCDate() + 1);
  return nextDay;
}

export interface AttendanceFilters {
  staffId?: string;
  siteId?: string;
  date?: Date;
  status?: AttendanceStatus;
}

export interface CreateAttendanceData {
  staffId: string;
  siteId: string;
  date: Date;
  status: AttendanceStatus;
  checkInTime?: Date;
  checkOutTime?: Date;
  checkInLatitude?: number;
  checkInLongitude?: number;
  checkInAccuracyMeters?: number;
  checkInCapturedAt?: Date;
  checkOutLatitude?: number;
  checkOutLongitude?: number;
  checkOutAccuracyMeters?: number;
  checkOutCapturedAt?: Date;
  checkInPhotoUrl?: string;
  checkOutPhotoUrl?: string;
  shiftType: ShiftType;
  overtimeHours?: number;
  markedById: string;
  notes?: string;
}

export class AttendanceRepository {
  async createAttendance(orgId: string, data: CreateAttendanceData) {
    return prisma.$transaction(async (tx) => {
      const attendanceDate = startUtcDay(data.date);
      const dayEnd = nextUtcDay(attendanceDate);
      await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtextextended(${`attendance:${orgId}:${data.staffId}:${attendanceDate.toISOString()}`}, 0))`;

      const [staff, site, assignment, existingRecord] = await Promise.all([
        tx.staff.findFirst({
          where: {
            id: data.staffId,
            orgId,
            deletedAt: null,
            status: StaffStatus.ACTIVE,
          },
          select: { id: true },
        }),
        tx.site.findFirst({
          where: {
            id: data.siteId,
            orgId,
            deletedAt: null,
            status: SiteStatus.ACTIVE,
          },
          select: { id: true, latitude: true, longitude: true, geoFenceRadius: true },
        }),
        tx.siteAssignment.findFirst({
          where: {
            orgId,
            siteId: data.siteId,
            staffId: data.staffId,
            removedAt: null,
            deletedAt: null,
          },
          select: { id: true },
        }),
        tx.attendanceRecord.findFirst({
          where: {
            orgId,
            staffId: data.staffId,
            date: { gte: attendanceDate, lt: dayEnd },
            deletedAt: null,
          },
          select: { id: true },
        }),
      ]);

      if (!staff) {
        throw new AppError('ATTENDANCE_STAFF_NOT_ELIGIBLE', 'The selected staff member is not active in this company.', 400);
      }
      if (!site) {
        throw new AppError('ATTENDANCE_SITE_NOT_ACTIVE', 'The selected site is not active in this company.', 400);
      }
      if (!assignment) {
        throw new AppError('ATTENDANCE_ASSIGNMENT_REQUIRED', 'The selected staff member is not actively assigned to this site.', 400);
      }
      if (existingRecord) {
        throw new AppError('ATTENDANCE_ALREADY_MARKED', 'Attendance has already been marked for this staff member and date.', 409);
      }

      const mapsProvider = new StoredCoordinateMapsProvider(tx);
      const checkInLocation = data.checkInLatitude !== undefined && data.checkInLongitude !== undefined
        ? await mapsProvider.validateLocation({
          organizationId: orgId,
          siteId: data.siteId,
          latitude: data.checkInLatitude,
          longitude: data.checkInLongitude,
          accuracyMeters: data.checkInAccuracyMeters,
          capturedAt: data.checkInCapturedAt ?? data.checkInTime ?? new Date(),
        })
        : null;
      const checkOutLocation = data.checkOutLatitude !== undefined && data.checkOutLongitude !== undefined
        ? await mapsProvider.validateLocation({
          organizationId: orgId,
          siteId: data.siteId,
          latitude: data.checkOutLatitude,
          longitude: data.checkOutLongitude,
          accuracyMeters: data.checkOutAccuracyMeters,
          capturedAt: data.checkOutCapturedAt ?? data.checkOutTime ?? new Date(),
        })
        : null;

      for (const location of [checkInLocation, checkOutLocation]) {
        if (location && !location.valid) {
          throw new AppError(`ATTENDANCE_LOCATION_${location.reason}`, `Attendance location validation failed: ${location.reason}.`, 400);
        }
      }

      return tx.attendanceRecord.create({
        data: {
          orgId,
          staffId: data.staffId,
          siteId: data.siteId,
          date: attendanceDate,
          status: data.status,
          shiftType: data.shiftType,
          markedById: data.markedById,
          ...(data.checkInTime !== undefined && { checkInTime: data.checkInTime }),
          ...(data.checkOutTime !== undefined && { checkOutTime: data.checkOutTime }),
          ...(data.checkInLatitude !== undefined && { checkInLatitude: data.checkInLatitude }),
          ...(data.checkInLongitude !== undefined && { checkInLongitude: data.checkInLongitude }),
          ...(data.checkInAccuracyMeters !== undefined && { checkInAccuracyMeters: data.checkInAccuracyMeters }),
          ...(data.checkInCapturedAt !== undefined && { checkInCapturedAt: data.checkInCapturedAt }),
          ...(checkInLocation?.distanceMeters !== null && checkInLocation?.distanceMeters !== undefined && { checkInDistanceMeters: checkInLocation.distanceMeters }),
          ...(checkInLocation && { checkInLocationValidation: checkInLocation.reason }),
          ...(data.checkOutLatitude !== undefined && { checkOutLatitude: data.checkOutLatitude }),
          ...(data.checkOutLongitude !== undefined && { checkOutLongitude: data.checkOutLongitude }),
          ...(data.checkOutAccuracyMeters !== undefined && { checkOutAccuracyMeters: data.checkOutAccuracyMeters }),
          ...(data.checkOutCapturedAt !== undefined && { checkOutCapturedAt: data.checkOutCapturedAt }),
          ...(checkOutLocation?.distanceMeters !== null && checkOutLocation?.distanceMeters !== undefined && { checkOutDistanceMeters: checkOutLocation.distanceMeters }),
          ...(checkOutLocation && { checkOutLocationValidation: checkOutLocation.reason }),
          ...(data.checkInPhotoUrl !== undefined && { checkInPhotoUrl: data.checkInPhotoUrl }),
          ...(data.checkOutPhotoUrl !== undefined && { checkOutPhotoUrl: data.checkOutPhotoUrl }),
          ...(data.overtimeHours !== undefined && { overtimeHours: data.overtimeHours }),
          ...(data.notes !== undefined && { notes: data.notes }),
        },
        include: attendanceInclude,
      });
    });
  }

  async getAttendanceRecords(orgId: string, filters: AttendanceFilters = {}) {
    return prisma.attendanceRecord.findMany({
      where: {
        orgId,
        deletedAt: null,
        ...(filters.staffId && { staffId: filters.staffId }),
        ...(filters.siteId && { siteId: filters.siteId }),
        ...(filters.date && {
          date: { gte: startUtcDay(filters.date), lt: nextUtcDay(filters.date) },
        }),
        ...(filters.status && { status: filters.status }),
      },
      include: attendanceInclude,
      orderBy: [{ date: 'desc' }, { createdAt: 'desc' }],
    });
  }

  async getAttendanceById(orgId: string, id: string) {
    return prisma.attendanceRecord.findFirst({
      where: { id, orgId, deletedAt: null },
      include: attendanceInclude,
    });
  }
}

export const attendanceRepository = new AttendanceRepository();
