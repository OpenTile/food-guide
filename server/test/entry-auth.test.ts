import { afterAll, beforeAll, expect, test } from "bun:test";
import { startTestServer, type TestServer } from "./harness.ts";

let server: TestServer;

beforeAll(async () => {
  server = await startTestServer();
});

afterAll(async () => {
  await server.close();
});

test("missing, malformed, and incorrect bearer tokens are rejected identically", async () => {
  const requests = [
    new Request("http://server/entries"),
    new Request("http://server/entries", {
      headers: { authorization: "Basic entry-api-token" },
    }),
    new Request("http://server/entries", {
      headers: { authorization: "Bearer incorrect" },
    }),
    new Request("http://server/entries/272e4f0a-f6aa-42b4-ac84-911c4c67df87", {
      method: "DELETE",
    }),
  ];

  const responses = await Promise.all(requests.map((request) => server.fetch(request)));
  const results = await Promise.all(
    responses.map(async (response) => ({
      status: response.status,
      contentType: response.headers.get("content-type"),
      body: await response.text(),
    })),
  );

  expect(results).toEqual([
    {
      status: 401,
      contentType: "application/json",
      body: '{"error":"unauthorized"}',
    },
    {
      status: 401,
      contentType: "application/json",
      body: '{"error":"unauthorized"}',
    },
    {
      status: 401,
      contentType: "application/json",
      body: '{"error":"unauthorized"}',
    },
    {
      status: 401,
      contentType: "application/json",
      body: '{"error":"unauthorized"}',
    },
  ]);
});
