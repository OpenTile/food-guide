export type Config = {
  databaseUrl: string;
  port: number;
};

/**
 * Reads deployment configuration from the environment.
 *
 * Throws if `DATABASE_URL` is absent, because a service that silently starts against the wrong
 * database is worse than one that refuses to start. `PORT` defaults to 3000.
 */
export function loadConfig(): Config {
  const databaseUrl = Bun.env.DATABASE_URL;
  if (!databaseUrl) throw new Error("DATABASE_URL is not set");

  return {
    databaseUrl,
    port: Number(Bun.env.PORT ?? 3000),
  };
}
