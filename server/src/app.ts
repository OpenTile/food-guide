import { Hono } from "hono";
import { createHash, timingSafeEqual } from "node:crypto";
import type { Entry, EntryStore } from "./entries/entry-store.ts";

export type AppDependencies = {
  bearerToken: string;
  entryStore: EntryStore;
};

const MAX_ENTRY_TEXT_LENGTH = 10_000;
const INSTANT_PATTERN =
  /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d+)?(?:Z|[+-](\d{2}):(\d{2}))$/i;

function tokenMatches(candidate: string, expected: string): boolean {
  const digest = (value: string) => createHash("sha256").update(value).digest();
  return timingSafeEqual(digest(candidate), digest(expected));
}

function entryJson(entry: Entry) {
  return {
    id: entry.id,
    text: entry.text,
    eatenAt: entry.eatenAt.toISOString(),
  };
}

function instantFromString(value: unknown): Date | undefined {
  if (typeof value !== "string") return undefined;

  const match = value.match(INSTANT_PATTERN);
  if (!match) return undefined;

  const year = Number(match[1]!);
  const month = Number(match[2]!);
  const day = Number(match[3]!);
  const hour = Number(match[4]!);
  const minute = Number(match[5]!);
  const second = Number(match[6]!);
  const offsetHour = Number(match[7] ?? 0);
  const offsetMinute = Number(match[8] ?? 0);
  const leapYear = year % 4 === 0 && (year % 100 !== 0 || year % 400 === 0);
  const monthLength =
    month === 2
      ? leapYear
        ? 29
        : 28
      : [4, 6, 9, 11].includes(month)
        ? 30
        : 31;

  if (
    month < 1 ||
    month > 12 ||
    day < 1 ||
    day > monthLength ||
    hour > 23 ||
    minute > 59 ||
    second > 59 ||
    offsetHour > 23 ||
    offsetMinute > 59
  ) {
    return undefined;
  }

  const instant = new Date(value);
  return Number.isNaN(instant.getTime()) ? undefined : instant;
}

function entryFromBody(body: unknown): Entry | undefined {
  if (!body || typeof body !== "object") return undefined;

  const { id, text, eatenAt } = body as Record<string, unknown>;
  if (
    typeof id !== "string" ||
    !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id) ||
    typeof text !== "string" ||
    text.trim().length === 0 ||
    Array.from(text).length > MAX_ENTRY_TEXT_LENGTH
  ) {
    return undefined;
  }

  const instant = instantFromString(eatenAt);
  if (!instant) return undefined;

  return { id, text, eatenAt: instant };
}

/**
 * Builds the application's request handler from its deployment token and Entry storage.
 *
 * Binds no socket, so a caller — the runtime in `index.ts`, or a test at Seam A — invokes it as
 * `app.fetch(request)` with a `Request` it constructed.
 */
export function createApp({ bearerToken, entryStore }: AppDependencies) {
  const app = new Hono();

  app.use("*", async (c, next) => {
    if (c.req.path === "/health") return next();

    const match = c.req.header("authorization")?.match(/^Bearer ([^\s]+)$/i);
    if (!match || !tokenMatches(match[1]!, bearerToken)) {
      return c.json({ error: "unauthorized" }, 401);
    }

    return next();
  });

  // Unauthenticated: the hosting platform probes this to decide whether the service is up.
  app.get("/health", (c) => c.json({ status: "ok" }));

  app.post("/entries", async (c) => {
    const entry = entryFromBody(await c.req.json().catch(() => undefined));
    if (!entry) return c.json({ error: "invalid_entry" }, 400);

    const result = await entryStore.create(entry);
    return c.json(entryJson(result.entry), result.inserted ? 201 : 200);
  });

  app.get("/entries", async (c) => {
    const from = instantFromString(c.req.query("from"));
    const to = instantFromString(c.req.query("to"));
    if (!from || !to) return c.json({ error: "invalid_range" }, 400);

    const entries = await entryStore.list({ from, to });
    return c.json(entries.map(entryJson));
  });

  return app;
}
