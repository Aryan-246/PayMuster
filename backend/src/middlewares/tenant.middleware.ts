import { Request, Response, NextFunction } from 'express';

import { prisma } from '../lib/prisma.js';

export const requireTenant = (options: {
  scope: 'COMPANY' | 'SITE';
  allowUnaffiliatedCompany?: boolean;
}) => {
  return async (req: Request, res: Response, next: NextFunction) => {
    const companyValue = req.params.companyId || req.headers['x-company-id'];
    const siteValue = req.params.siteId || req.headers['x-site-id'];
    let companyId = typeof companyValue === 'string' ? companyValue : Array.isArray(companyValue) ? companyValue[0] : undefined;
    const siteId = typeof siteValue === 'string' ? siteValue : Array.isArray(siteValue) ? siteValue[0] : undefined;
    const user = req.context?.user;

    if (options.scope === 'COMPANY' && !companyId) {
      res.status(400).json({ success: false, error: { code: 'TENANT_REQUIRED', message: 'Company ID is required for this route.' } });
      return;
    }

    if (options.scope === 'SITE' && !siteId) {
      res.status(400).json({ success: false, error: { code: 'TENANT_REQUIRED', message: 'Site ID is required for this route.' } });
      return;
    }

    if (!user) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Authenticated user context is required.' } });
      return;
    }

    if (siteId) {
      const site = await prisma.site.findUnique({
        where: { id: siteId },
        select: { id: true, orgId: true },
      });
      if (!site || (companyId && site.orgId !== companyId)) {
        res.status(403).json({ success: false, error: { code: 'TENANT_FORBIDDEN', message: 'You do not have access to this site.' } });
        return;
      }

      // A Site is the authoritative source for its organization. A header may
      // confirm that context, but must never be able to choose another tenant.
      companyId = site.orgId;
    }

    const mayTargetCompany =
      user.orgId === companyId ||
      (options.allowUnaffiliatedCompany === true && user.orgId === null);
    if (!mayTargetCompany) {
      res.status(403).json({ success: false, error: { code: 'TENANT_FORBIDDEN', message: 'You do not have access to this company.' } });
      return;
    }

    req.context.tenant = { companyId, siteId };
    next();
  };
};
