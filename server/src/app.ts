import { Hono } from "hono";
import { bearerAuthentication } from "./auth/bearer-authentication.ts";
import { createEntryRouter } from "./entries/entry-router.ts";
import type { EntryStore } from "./entries/entry-store.ts";

export type AppDependencies = {
  bearerToken: string;
  entryStore: EntryStore;
};

/**
 * Builds the application's request handler from its deployment token and Entry storage.
 *
 * Binds no socket, so a caller — the runtime in `index.ts`, or a test at Seam A — invokes it as
 * `app.fetch(request)` with a `Request` it constructed.
 */
export function createApp({ bearerToken, entryStore }: AppDependencies) {
  const app = new Hono();

  // Unauthenticated: the hosting platform probes this to decide whether the service is up.
  app.get("/health", (c) => c.json({ status: "ok" }));
  app.use("*", bearerAuthentication(bearerToken));
  app.route("/entries", createEntryRouter(entryStore));

  return app;
}
