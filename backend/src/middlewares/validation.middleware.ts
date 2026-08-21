import { Request, Response, NextFunction } from 'express';
import { ZodSchema, ZodError } from 'zod';

function validationError(res: Response, error: unknown): Response {
  if (error instanceof ZodError) {
    return res.status(400).json({
      success: false,
      error: {
        code: 'VALIDATION_ERROR',
        message: 'Invalid request data',
        details: error.issues,
      },
    });
  }
  return res.status(500).json({
    success: false,
    error: { code: 'INTERNAL_ERROR', message: 'Internal Server Error' },
  });
}

export const validateRequest = (schema: ZodSchema) => {
  return async (req: Request, res: Response, next: NextFunction) => {
    try {
      req.body = await schema.parseAsync(req.body);
      next();
    } catch (error) {
      return validationError(res, error);
    }
  };
};

export const validateQuery = (schema: ZodSchema, localKey = 'validatedQuery') => {
  return async (req: Request, res: Response, next: NextFunction) => {
    try {
      res.locals[localKey] = await schema.parseAsync(req.query);
      next();
    } catch (error) {
      return validationError(res, error);
    }
  };
};

export const validateParams = (schema: ZodSchema, localKey = 'validatedParams') => {
  return async (req: Request, res: Response, next: NextFunction) => {
    try {
      res.locals[localKey] = await schema.parseAsync(req.params);
      next();
    } catch (error) {
      return validationError(res, error);
    }
  };
};
