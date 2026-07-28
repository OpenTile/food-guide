import { afterAll, beforeAll, expect, test } from "bun:test";
import { startTestServer, type TestServer } from "./harness.ts";

let server: TestServer;

beforeAll(async () => {
  server = await startTestServer();
});

afterAll(async () => {
  await server.close();
});

test("a health request succeeds without authentication", async () => {
  const response = await server.fetch(new Request("http://server/health"));

  expect(response.status).toBe(200);
  expect(await response.json()).toEqual({ status: "ok" });
});
