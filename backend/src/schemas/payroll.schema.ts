import { z } from 'zod';

const moneySchema = z.number().finite().min(0).max(1_000_000_000);
const adjustmentsSchema = z.record(z.string().trim().min(1).max(80), moneySchema);

export const createPayrollSchema = z
    .object({
        payCycleId: z.string().uuid(),
        items: z
            .array(
                z
                    .object({
                        staffId: z.string().uuid(),
                        grossPay: moneySchema,
                        deductions: adjustmentsSchema.default({}),
                        additions: adjustmentsSchema.default({}),
                        arrears: adjustmentsSchema.default({}),
                    })
                    .strict(),
            )
            .min(1)
            .max(10_000),
    })
    .strict()
    .superRefine((value, context) => {
        const staffIds = new Set<string>();
        for (const [index, item] of value.items.entries()) {
            if (staffIds.has(item.staffId)) {
                context.addIssue({
                    code: 'custom',
                    path: ['items', index, 'staffId'],
                    message: 'A staff member can appear only once in a pay run.',
                });
            }
            staffIds.add(item.staffId);

            const deductionTotal = Object.values(item.deductions).reduce((sum, amount) => sum + amount, 0);
            const additionTotal = Object.values(item.additions).reduce((sum, amount) => sum + amount, 0);
            const arrearsTotal = Object.values(item.arrears).reduce((sum, amount) => sum + amount, 0);
            if (item.grossPay - deductionTotal + additionTotal + arrearsTotal < 0) {
                context.addIssue({
                    code: 'custom',
                    path: ['items', index, 'deductions'],
                    message: 'Payroll adjustments cannot produce negative net pay.',
                });
            }
        }
    });

export const listPayrollQuerySchema = z
    .object({
        payCycleId: z.string().uuid().optional(),
    })
    .strict();
