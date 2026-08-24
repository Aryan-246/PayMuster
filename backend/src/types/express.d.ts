import { AppContext } from './context.js';

declare global {
  namespace Express {
    interface Request {
      id: string;
      context: AppContext;
      rawBody?: Buffer;
    }
  }
}
