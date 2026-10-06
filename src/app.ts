import Fastify, { FastifyInstance } from 'fastify';

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
export function buildApp(): FastifyInstance {
  const app = Fastify({ logger: false });

  // Liveness/health probe. Returns a small JSON payload describing the
  // process state. Kept dependency-free so it stays fast and always available.
  app.get('/health', async (): Promise<HealthResponse> => {
    return {
      status: 'ok',
      uptime: process.uptime(),
      timestamp: new Date().toISOString(),
    };
  });

  return app;
}
