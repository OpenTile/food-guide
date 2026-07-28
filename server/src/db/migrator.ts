import type { SQL } from "bun";
import { readdir } from "node:fs/promises";

const MIGRATIONS = new URL("./migrations/", import.meta.url);

/**
 * Applies every migration not yet recorded, in filename order, and returns the names applied.
 *
 * Called at boot. A second call applies nothing, so restarting and redeploying are safe.
 * Each migration and its record commit together, so a failure leaves nothing half-applied.
 */
export async function migrate(sql: SQL): Promise<string[]> {
  await sql`
    create table if not exists schema_migrations (
      name text primary key,
      applied_at timestamptz not null default now()
    )
  `;

  const recorded = new Set(
    (await sql`select name from schema_migrations`).map(
      (row: { name: string }) => row.name,
    ),
  );
  const pending = (await readdir(MIGRATIONS))
    .filter((name) => name.endsWith(".sql"))
    .sort()
    .filter((name) => !recorded.has(name));

  for (const name of pending) {
    const statements = await Bun.file(new URL(name, MIGRATIONS)).text();
    await sql.begin(async (tx) => {
      await tx.unsafe(statements);
      await tx`insert into schema_migrations (name) values (${name})`;
    });
  }

  return pending;
}
