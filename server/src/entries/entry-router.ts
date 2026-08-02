import { Hono } from "hono";
import type { Entry, EntryStore } from "./entry-store.ts";

const MAX_ENTRY_TEXT_LENGTH = 10_000;
const INSTANT_PATTERN =
  /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d+)?(?:Z|[+-](\d{2}):(\d{2}))$/i;

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

/** Builds the authenticated HTTP routes for creating and listing Entries. */
export function createEntryRouter(entryStore: EntryStore): Hono {
  const router = new Hono();

  router.post("/", async (c) => {
    const entry = entryFromBody(await c.req.json().catch(() => undefined));
    if (!entry) return c.json({ error: "invalid_entry" }, 400);

    const result = await entryStore.create(entry);
    return c.json(entryJson(result.entry), result.inserted ? 201 : 200);
  });

  router.get("/", async (c) => {
    const from = instantFromString(c.req.query("from"));
    const to = instantFromString(c.req.query("to"));
    if (!from || !to) return c.json({ error: "invalid_range" }, 400);

    const entries = await entryStore.list({ from, to });
    return c.json(entries.map(entryJson));
  });

  return router;
}
