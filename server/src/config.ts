export type Config = {
  bearerToken: string;
  databaseUrl: string;
  port: number;
};

/**
 * Reads deployment configuration from the environment.
 *
 * Throws if `DATABASE_URL` or `BEARER_TOKEN` is absent, because a service that silently starts
 * with incomplete configuration is worse than one that refuses to start. `PORT` defaults to 3000.
 */
export function loadConfig(): Config {
  const bearerToken = Bun.env.BEARER_TOKEN;
  const databaseUrl = Bun.env.DATABASE_URL;
  if (!databaseUrl) throw new Error("DATABASE_URL is not set");
  if (!bearerToken) throw new Error("BEARER_TOKEN is not set");

  return {
    bearerToken,
    databaseUrl,
    port: Number(Bun.env.PORT ?? 3000),
  };
}
