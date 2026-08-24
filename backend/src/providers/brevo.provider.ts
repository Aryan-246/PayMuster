import nodemailer from 'nodemailer';
import { config } from '../lib/config.js';
import { logger } from '../lib/logger.js';
import type { ProviderHealth } from './contracts.js';

function now(): string {
    return new Date().toISOString();
}

/**
 * Brevo email provider — optional SMTP transport alternative to Gmail/Nodemailer.
 * Uses Brevo's SMTP relay (smtp-relay.brevo.com:587) with the provided credentials.
 */
export class BrevoProvider {
    private transporter: nodemailer.Transporter | null = null;
    private initError: string | null = null;

    private getTransporter(): nodemailer.Transporter | null {
        if (this.transporter) return this.transporter;
        if (this.initError) return null;

        if (!config.brevoEnabled || !config.brevoSmtpKey || !config.brevoSmtpLogin) {
            this.initError = 'Brevo is not enabled or SMTP credentials are missing.';
            return null;
        }

        try {
            this.transporter = nodemailer.createTransport({
                host: config.brevoSmtpHost,
                port: config.brevoSmtpPort,
                secure: false, // Brevo uses STARTTLS on port 587
                auth: {
                    user: config.brevoSmtpLogin,
                    pass: config.brevoSmtpKey,
                },
                connectionTimeout: 10_000,
                greetingTimeout: 10_000,
                socketTimeout: 15_000,
            });
            return this.transporter;
        } catch (err: any) {
            this.initError = `Failed to create Brevo transporter: ${err.message}`;
            logger.error('brevo.init_failed', err);
            return null;
        }
    }

    async health(): Promise<ProviderHealth> {
        if (!config.brevoEnabled) {
            return {
                provider: 'brevo',
                kind: 'EMAIL',
                status: 'DISABLED',
                readiness: 'DISABLED',
                enabled: false,
                fallback: 'smtp-nodemailer',
                checkedAt: now(),
                detail: 'Brevo email delivery is disabled.',
            };
        }

        const transporter = this.getTransporter();
        if (!transporter) {
            return {
                provider: 'brevo',
                kind: 'EMAIL',
                status: 'INVALID_CONFIGURATION',
                readiness: 'MISSING_CONFIGURATION',
                enabled: true,
                fallback: 'smtp-nodemailer',
                checkedAt: now(),
                detail: this.initError || 'Brevo transporter not available.',
            };
        }

        try {
            await transporter.verify();
            return {
                provider: 'brevo',
                kind: 'EMAIL',
                status: 'CONNECTED',
                readiness: 'READY',
                enabled: true,
                fallback: 'smtp-nodemailer',
                checkedAt: now(),
                detail: 'Brevo SMTP relay is reachable and authenticated.',
            };
        } catch (err: any) {
            const isAuthError = err.code === 'EAUTH' || err.responseCode === 535;
            return {
                provider: 'brevo',
                kind: 'EMAIL',
                status: 'UNAVAILABLE',
                readiness: isAuthError ? 'INVALID_CONFIGURATION' : 'ENVIRONMENT_BLOCKED',
                enabled: true,
                fallback: 'smtp-nodemailer',
                checkedAt: now(),
                detail: isAuthError
                    ? 'Brevo credentials rejected: authentication check failed (INVALID_CREDENTIAL).'
                    : `Brevo verification failed: ${err.message}`,
            };
        }
    }

    async sendMail(options: {
        to: string;
        subject: string;
        html: string;
        from?: string;
    }): Promise<{ success: boolean; messageId?: string; error?: string }> {
        const transporter = this.getTransporter();
        if (!transporter) {
            return { success: false, error: 'Brevo transporter not available' };
        }

        try {
            const result = await transporter.sendMail({
                from: options.from || config.emailFrom,
                to: options.to,
                subject: options.subject,
                html: options.html,
            });

            logger.info('brevo.mail_sent', { to: options.to, messageId: result.messageId });
            return { success: true, messageId: result.messageId };
        } catch (err: any) {
            logger.error('brevo.send_failed', err, { to: options.to });
            return { success: false, error: err.message };
        }
    }

    async testConnection(): Promise<{
        reachable: boolean;
        authenticated: boolean;
        authRejected?: boolean;
        responseCode?: number;
        error?: string;
    }> {
        const transporter = this.getTransporter();
        if (!transporter) {
            return { reachable: false, authenticated: false, error: this.initError || 'Transporter not available' };
        }

        try {
            await transporter.verify();
            return { reachable: true, authenticated: true };
        } catch (err: any) {
            // Precise classification: only SMTP 535 (5.7.8 "auth credentials
            // invalid") is a genuine credential rejection. Brevo returns 525
            // (5.7.1 "Unauthorized IP address") when the key is valid but the
            // sending IP is not whitelisted — nodemailer labels that EAUTH too,
            // so we key off the SMTP response code, never err.code. A missing
            // responseCode means no SMTP reply at all (transport failure).
            const authRejected = err.responseCode === 535;
            const gotServerReply = typeof err.responseCode === 'number' || err.code === 'EAUTH';
            return {
                reachable: gotServerReply,
                authenticated: false,
                authRejected,
                responseCode: typeof err.responseCode === 'number' ? err.responseCode : undefined,
                error: err.response || err.message,
            };
        }
    }
}

export const brevoProvider = new BrevoProvider();
