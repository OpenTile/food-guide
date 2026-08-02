import { createHash, timingSafeEqual } from "node:crypto";
import type { MiddlewareHandler } from "hono";

function tokenMatches(candidate: string, expected: string): boolean {
  const digest = (value: string) => createHash("sha256").update(value).digest();
  return timingSafeEqual(digest(candidate), digest(expected));
}

/**
 * Authenticates routes registered after this middleware with a bearer token.
 *
 * Missing, malformed, and incorrect credentials receive the same unauthorized response.
 */
export function bearerAuthentication(expectedToken: string): MiddlewareHandler {
  return async (c, next) => {
    const match = c.req.header("authorization")?.match(/^Bearer ([^\s]+)$/i);
    if (!match || !tokenMatches(match[1]!, expectedToken)) {
      return c.json({ error: "unauthorized" }, 401);
    }

    return next();
  };
}
