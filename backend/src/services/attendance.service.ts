import {
  attendanceRepository,
  type AttendanceFilters,
} from '../repositories/attendance.repository.js';
import { AppError } from '../lib/app-error.js';
import { eventBus, Events } from '../lib/events.js';
import { AttendanceStatus, ShiftType } from '../../generated/prisma/index.js';

export class AttendanceService {
  async listAttendance(orgId: string, filters: AttendanceFilters = {}) {
    return attendanceRepository.getAttendanceRecords(orgId, filters);
  }

  async createAttendance(orgId: string, userId: string, data: {
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
    notes?: string;
  }) {
    const record = await attendanceRepository.createAttendance(orgId, {
      ...data,
      markedById: userId,
    });

    eventBus.emitEvent(Events.ATTENDANCE_MARKED, {
      attendanceId: record.id,
      orgId,
      staffId: data.staffId,
      date: record.date,
      status: data.status,
    });

    return record;
  }

  async getAttendance(orgId: string, userId: string, id: string) {
    const record = await attendanceRepository.getAttendanceById(orgId, id);
    if (!record) {
      throw new AppError('ATTENDANCE_NOT_FOUND', 'Attendance record not found', 404);
    }
    return record;
  }
}

export const attendanceService = new AttendanceService();
