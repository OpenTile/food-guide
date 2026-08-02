import { SQL } from "bun";
import { createApp } from "./app.ts";
import { loadConfig } from "./config.ts";
import { migrate } from "./db/migrator.ts";
import { PostgresEntryStore } from "./db/postgres-entry-store.ts";

const config = loadConfig();
const sql = new SQL(config.databaseUrl);

const applied = await migrate(sql);
console.log(
  applied.length > 0
    ? `Applied migrations: ${applied.join(", ")}`
    : "Migrations up to date",
);

export default {
  port: config.port,
  fetch: createApp({
    bearerToken: config.bearerToken,
    entryStore: new PostgresEntryStore(sql),
  }).fetch,
};
