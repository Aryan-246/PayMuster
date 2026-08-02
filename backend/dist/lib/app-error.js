export class AppError extends Error {
    code;
    status;
    retryAfterSeconds;
    constructor(code, message, status = 400, options = {}) {
        super(message);
        this.name = 'AppError';
        this.code = code;
        this.status = status;
        this.retryAfterSeconds = options.retryAfterSeconds;
    }
}
export function isAppError(error) {
    return error instanceof AppError;
}
