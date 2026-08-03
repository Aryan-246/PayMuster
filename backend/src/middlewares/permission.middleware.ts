import { Request, Response, NextFunction } from 'express';
import { PermissionAction, RolePermissions } from '../lib/permissions.js';

export const requirePermission = (action: PermissionAction) => {
  return (req: Request, res: Response, next: NextFunction) => {
    const userRole = req.context?.user?.role;

    if (!userRole) {
      return res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'User role not found in context.' } });
    }

    const permissions = RolePermissions[userRole] || [];

    if (!permissions.includes(action)) {
      return res.status(403).json({ success: false, error: { code: 'FORBIDDEN', message: `Missing required permission: ${action}` } });
    }

    next();
  };
};
