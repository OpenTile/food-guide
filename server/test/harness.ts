import { SQL } from "bun";
import { randomUUID } from "node:crypto";
import {
  PostgreSqlContainer,
  type StartedPostgreSqlContainer,
} from "@testcontainers/postgresql";
import { createApp } from "../src/app.ts";
import { migrate } from "../src/db/migrator.ts";

/**
 * Seam A: the server's HTTP boundary.
 *
 * Tests build a `Request` and hand it to `fetch` directly — no socket is bound — while
 * everything below the boundary runs as it does in production, against a real Postgres.
 */
export type TestServer = {
  /** Invokes the application's request handler, exactly as the runtime would. */
  fetch: (request: Request) => Response | Promise<Response>;
  close: () => Promise<void>;
};

let container: Promise<StartedPostgreSqlContainer> | undefined;

/** One container for the whole run; each caller gets its own database inside it. */
function postgresContainer(): Promise<StartedPostgreSqlContainer> {
  container ??= new PostgreSqlContainer("postgres:17-alpine").start();
  return container;
}

/** Torn down for the whole run by `test/setup.ts`; tests do not call this. */
export async function stopPostgres(): Promise<void> {
  const started = await container;
  container = undefined;
  await started?.stop();
}

/**
 * Starts a server on a freshly migrated database, isolated from every other test file.
 *
 * ```ts
 * const server = await startTestServer();
 * const response = await server.fetch(new Request("http://server/health"));
 * ```
 *
 * Always `close()` it, otherwise the run will not exit.
 */
export async function startTestServer(): Promise<TestServer> {
  const sql = await createTestDatabase();
  await migrate(sql);

  return {
    fetch: createApp().fetch,
    close: () => sql.close(),
  };
}

/** A connection to an empty, unmigrated database — for testing the migrator itself. */
export async function createTestDatabase(): Promise<SQL> {
  const started = await postgresContainer();
  const name = `test_${randomUUID().replaceAll("-", "")}`;

  const admin = new SQL(started.getConnectionUri());
  await admin.unsafe(`create database "${name}"`);
  await admin.close();

  return new SQL({
    hostname: started.getHost(),
    port: started.getMappedPort(5432),
    username: started.getUsername(),
    password: started.getPassword(),
    database: name,
  });
}
