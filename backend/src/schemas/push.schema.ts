import { z } from 'zod';

export const registerDeviceSchema = z.object({
    token: z.string().trim().min(20).max(4096),
    platform: z.enum(['ANDROID', 'IOS', 'WEB']),
    appVersion: z.string().trim().max(80).optional(),
    deviceId: z.string().trim().max(200).optional(),
}).strict();

export const unregisterDeviceSchema = z.object({
    token: z.string().trim().min(20).max(4096),
}).strict();
