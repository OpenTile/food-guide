import type { SQL } from "bun";
import type {
  CreateEntryResult,
  Entry,
  EntryRange,
  EntryStore,
} from "../entries/entry-store.ts";

type EntryRow = {
  id: string;
  text: string;
  eaten_at: Date;
};

function entryFromRow(row: EntryRow): Entry {
  return {
    id: row.id,
    text: row.text,
    eatenAt: new Date(row.eaten_at),
  };
}

/** Postgres-backed Entry storage used by the live server and Seam A tests. */
export class PostgresEntryStore implements EntryStore {
  constructor(private readonly sql: SQL) {}

  async create(entry: Entry): Promise<CreateEntryResult> {
    const [inserted] = await this.sql<EntryRow[]>`
      insert into entries (id, text, eaten_at)
      values (${entry.id}, ${entry.text}, ${entry.eatenAt})
      on conflict (id) do nothing
      returning id::text, text, eaten_at
    `;

    if (inserted) return { entry: entryFromRow(inserted), inserted: true };

    const [existing] = await this.sql<EntryRow[]>`
      select id::text, text, eaten_at from entries where id = ${entry.id}
    `;
    if (!existing) throw new Error("Entry disappeared after an identifier conflict");

    return { entry: entryFromRow(existing), inserted: false };
  }

  async list({ from, to }: EntryRange): Promise<Entry[]> {
    const rows = await this.sql<EntryRow[]>`
      select id::text, text, eaten_at
      from entries
      where eaten_at >= ${from} and eaten_at < ${to}
      order by eaten_at asc, id asc
    `;
    return rows.map(entryFromRow);
  }

  async delete(id: string): Promise<void> {
    await this.sql`delete from entries where id = ${id}`;
  }
}
