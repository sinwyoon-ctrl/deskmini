import { buildApp } from './app.js';
const PORT = Number(process.env.PORT ?? 3000);
const HOST = process.env.HOST ?? '0.0.0.0';
const app = buildApp();
app
    .listen({ port: PORT, host: HOST })
    .then((address) => {
    // eslint-disable-next-line no-console
    console.log(`health-api listening at ${address}`);
})
    .catch((err) => {
    app.log.error(err);
    process.exit(1);
});
//# sourceMappingURL=server.js.map