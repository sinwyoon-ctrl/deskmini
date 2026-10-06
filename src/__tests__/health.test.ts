import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import type { FastifyInstance } from 'fastify';
import { buildApp, type HealthResponse } from '../app.js';

describe('GET /health', () => {
  let app: FastifyInstance;

  beforeAll(async () => {
    app = buildApp();
    await app.ready();
  });

  afterAll(async () => {
    await app.close();
  });

  it('responds with HTTP 200', async () => {
    const res = await app.inject({ method: 'GET', url: '/health' });
    expect(res.statusCode).toBe(200);
  });

  it('returns JSON with status "ok"', async () => {
    const res = await app.inject({ method: 'GET', url: '/health' });
    const body = res.json<HealthResponse>();
    expect(body.status).toBe('ok');
  });

  it('includes a non-negative numeric uptime', async () => {
    const res = await app.inject({ method: 'GET', url: '/health' });
    const body = res.json<HealthResponse>();
    expect(typeof body.uptime).toBe('number');
    expect(body.uptime).toBeGreaterThanOrEqual(0);
  });

  it('includes a valid ISO timestamp', async () => {
    const res = await app.inject({ method: 'GET', url: '/health' });
    const body = res.json<HealthResponse>();
    expect(Number.isNaN(Date.parse(body.timestamp))).toBe(false);
  });

  it('returns 404 for an unknown route', async () => {
    const res = await app.inject({ method: 'GET', url: '/does-not-exist' });
    expect(res.statusCode).toBe(404);
  });
});
