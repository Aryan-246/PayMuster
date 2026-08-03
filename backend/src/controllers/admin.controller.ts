import { Request, Response } from 'express';
import { adminService } from '../services/admin.service.js';

export class AdminController {
  async searchUsers(req: Request, res: Response) {
    const query = req.query.q as string;
    const users = await adminService.searchUsers(query);
    res.status(200).json({ success: true, data: users, meta: { requestId: req.id } });
  }

  async userAction(req: Request, res: Response) {
    const targetUserId = req.params.id as string;
    const actionBy = req.context.user!.id;
    const { action, role } = req.body;
    
    const result = await adminService.executeAction(targetUserId, actionBy, action, role);
    res.status(200).json({ success: true, data: result, meta: { requestId: req.id } });
  }
}

export const adminController = new AdminController();
