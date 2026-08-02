import { afterEach, beforeEach, expect, test } from "bun:test";
import type { SQL } from "bun";
import { migrate } from "../src/db/migrator.ts";
import { createTestDatabase } from "./harness.ts";

let sql: SQL;

beforeEach(async () => {
  sql = await createTestDatabase();
});

afterEach(async () => {
  await sql.close();
});

/** Everything a later migration could change: columns, their types, and indexes. */
async function schemaSnapshot(sql: SQL) {
  const columns = await sql`
    select table_name, column_name, data_type, is_nullable
    from information_schema.columns
    where table_schema = 'public'
    order by table_name, column_name
  `;
  const indexes = await sql`
    select indexname, indexdef from pg_indexes
    where schemaname = 'public'
    order by indexname
  `;
  return { columns, indexes };
}

test("a first start applies the pending migrations in order", async () => {
  const applied = await migrate(sql);

  expect(applied).toEqual(["0001_create_entries.sql"]);
});

test("a second start applies nothing and leaves the schema identical", async () => {
  await migrate(sql);
  const before = await schemaSnapshot(sql);

  const applied = await migrate(sql);

  expect(applied).toEqual([]);
  expect(await schemaSnapshot(sql)).toEqual(before);
});

test("storage for an Entry has an identifier, text, and Eaten At as an instant", async () => {
  await migrate(sql);

  const columns = await sql`
    select column_name, data_type, is_nullable
    from information_schema.columns
    where table_schema = 'public' and table_name = 'entries'
    order by column_name
  `;

  expect(columns).toEqual([
    { column_name: "eaten_at", data_type: "timestamp with time zone", is_nullable: "NO" },
    { column_name: "id", data_type: "uuid", is_nullable: "NO" },
    { column_name: "text", data_type: "text", is_nullable: "NO" },
  ]);
});

test("Eaten At is indexed, because every read filters on a range of it", async () => {
  await migrate(sql);

  const [index] = await sql`
    select indexdef from pg_indexes
    where schemaname = 'public' and tablename = 'entries' and indexdef like '%eaten_at%'
  `;

  expect(index?.indexdef).toContain("(eaten_at)");
});
