import { buildApp } from './app.js';

const PORT = Number(process.env.PORT ?? 3000);
const HOST = process.env.HOST ?? '0.0.0.0';

const app = buildApp();

const shutdown = async (signal: string) => {
  // eslint-disable-next-line no-console
  console.log(`Received ${signal}, shutting down gracefully...`);
  try {
    await app.close();
    // eslint-disable-next-line no-console
    console.log('Server closed successfully.');
    process.exit(0);
  } catch (err) {
    console.error('Error during shutdown:', err);
    process.exit(1);
  }
};

process.on('SIGTERM', () => {
  void shutdown('SIGTERM');
});
process.on('SIGINT', () => {
  void shutdown('SIGINT');
});

app
  .listen({ port: PORT, host: HOST })
  .then((address) => {
    // eslint-disable-next-line no-console
    console.log(`deskmini listening at ${address}`);
  })
  .catch((err) => {
    console.error('Failed to start deskmini server:', err);
    process.exit(1);
  });