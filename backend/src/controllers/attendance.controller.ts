import { Request, Response } from 'express';
import { AttendanceStatus } from '../../generated/prisma/index.js';
import { attendanceService } from '../services/attendance.service.js';

interface AttendanceQuery {
  staffId?: string;
  siteId?: string;
  date?: string;
  status?: AttendanceStatus;
}

export class AttendanceController {
  async listAttendance(req: Request, res: Response) {
    const companyId = req.context.tenant!.companyId!;
    const query = res.locals.validatedQuery as AttendanceQuery;
    const records = await attendanceService.listAttendance(companyId, {
      staffId: query.staffId,
      siteId: query.siteId,
      status: query.status,
      ...(query.date && { date: new Date(`${query.date}T00:00:00.000Z`) }),
    });
    res.status(200).json({ success: true, data: records, meta: { requestId: req.id } });
  }

  async createAttendance(req: Request, res: Response) {
    const companyId = req.context.tenant!.companyId!;
    const userId = req.context.user!.id;

    const record = await attendanceService.createAttendance(companyId, userId, req.body);
    res.status(201).json({ success: true, data: record, meta: { requestId: req.id } });
  }

  async getAttendance(req: Request, res: Response) {
    const companyId = req.context.tenant!.companyId!;
    const userId = req.context.user!.id;
    const id = req.params.id as string;

    const record = await attendanceService.getAttendance(companyId, userId, id);
    res.status(200).json({ success: true, data: record, meta: { requestId: req.id } });
  }
}

export const attendanceController = new AttendanceController();
