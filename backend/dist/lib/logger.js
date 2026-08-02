const sensitiveFieldPattern = /password|otp|token|secret|authorization|cookie|credential/i;
function sanitize(value, fieldName = '') {
    if (sensitiveFieldPattern.test(fieldName)) {
        return '[REDACTED]';
    }
    if (typeof value === 'string') {
        return value.length > 500 ? value.slice(0, 500) + '…' : value;
    }
    if (Array.isArray(value)) {
        return value.map((item) => sanitize(item));
    }
    if (value && typeof value === 'object') {
        return Object.fromEntries(Object.entries(value).map(([key, item]) => [key, sanitize(item, key)]));
    }
    return value;
}
function serializeError(error) {
    if (error instanceof Error) {
        const candidate = error;
        return {
            name: error.name,
            message: error.message,
            code: candidate.code,
            status: candidate.status,
        };
    }
    return { value: sanitize(error) };
}
function write(level, event, fields = {}) {
    const sanitizedFields = sanitize(fields);
    const record = {
        timestamp: new Date().toISOString(),
        level,
        event,
        ...sanitizedFields,
    };
    const output = JSON.stringify(record);
    if (level === 'error') {
        console.error(output);
        return;
    }
    if (level === 'warn') {
        console.warn(output);
        return;
    }
    console.info(output);
}
export const logger = {
    info(event, fields) {
        write('info', event, fields);
    },
    warn(event, fields) {
        write('warn', event, fields);
    },
    error(event, error, fields) {
        write('error', event, { ...fields, error: serializeError(error) });
    },
};
export function maskEmail(email) {
    const atIndex = email.indexOf('@');
    if (atIndex <= 1) {
        return '***';
    }
    return email.slice(0, 1) + '***' + email.slice(atIndex);
}
