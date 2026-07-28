import { Hono } from "hono";

/**
 * Builds the application's request handler.
 *
 * Binds no socket, so a caller — the runtime in `index.ts`, or a test at Seam A — invokes it as
 * `app.fetch(request)` with a `Request` it constructed.
 */
export function createApp() {
  const app = new Hono();

  // Unauthenticated: the hosting platform probes this to decide whether the service is up.
  app.get("/health", (c) => c.json({ status: "ok" }));

  return app;
}
