import { Router } from 'express';
import { attendanceController } from '../controllers/attendance.controller.js';
import { requireAuth } from '../middlewares/auth.js';
import { requireTenant } from '../middlewares/tenant.middleware.js';
import { requirePermission } from '../middlewares/permission.middleware.js';
import { validateQuery, validateRequest } from '../middlewares/validation.middleware.js';
import { auditMiddleware } from '../middlewares/audit.middleware.js';
import {
  createAttendanceSchema,
  listAttendanceQuerySchema,
} from '../schemas/attendance.schema.js';

const router = Router();

router.use(requireAuth);

router.get('/',
  requireTenant({ scope: 'COMPANY' }),
  requirePermission('view_attendance'),
  validateQuery(listAttendanceQuerySchema),
  auditMiddleware,
  attendanceController.listAttendance.bind(attendanceController)
);

router.post('/',
  requireTenant({ scope: 'COMPANY' }),
  requirePermission('manage_attendance'),
  validateRequest(createAttendanceSchema),
  auditMiddleware,
  attendanceController.createAttendance.bind(attendanceController)
);

router.get('/:id',
  requireTenant({ scope: 'COMPANY' }),
  requirePermission('view_attendance'),
  auditMiddleware,
  attendanceController.getAttendance.bind(attendanceController)
);

export default router;
