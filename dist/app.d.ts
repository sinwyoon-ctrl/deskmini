import { FastifyInstance } from 'fastify';
export interface HealthResponse {
    status: 'ok';
    uptime: number;
    timestamp: string;
}
/**
 * Build and configure the Fastify application instance.
 *
 * The app is created separately from the server bootstrap so that it can be
 * exercised in unit tests via `app.inject()` without binding to a real port.
 */
export declare function buildApp(): FastifyInstance;
