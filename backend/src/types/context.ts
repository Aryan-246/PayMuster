export interface AppContext {
  requestId: string;
  user?: {
    id: string;
    email: string;
    role: string;
  };
  tenant?: {
    companyId?: string;
    siteId?: string;
  };
}
