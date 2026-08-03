import { Request, Response, NextFunction } from 'express';

export const requireTenant = (options: { scope: 'COMPANY' | 'SITE' }) => {
  return (req: Request, res: Response, next: NextFunction) => {
    const companyId = req.params.companyId || req.headers['x-company-id'] as string | undefined;
    const siteId = req.params.siteId || req.headers['x-site-id'] as string | undefined;

    if (options.scope === 'COMPANY' && !companyId) {
      return res.status(400).json({ success: false, error: { code: 'TENANT_REQUIRED', message: 'Company ID is required for this route.' } });
    }

    if (options.scope === 'SITE' && !siteId) {
      return res.status(400).json({ success: false, error: { code: 'TENANT_REQUIRED', message: 'Site ID is required for this route.' } });
    }

    req.context.tenant = {
      companyId: typeof companyId === 'string' ? companyId : Array.isArray(companyId) ? companyId[0] : undefined,
      siteId: typeof siteId === 'string' ? siteId : Array.isArray(siteId) ? siteId[0] : undefined,
    };

    next();
  };
};
