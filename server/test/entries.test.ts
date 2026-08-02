import { afterAll, beforeAll, expect, test } from "bun:test";
import {
  startTestServer,
  TEST_BEARER_TOKEN,
  type TestServer,
} from "./harness.ts";

let server: TestServer;

type EntryJson = {
  id: string;
  text: string;
  eatenAt: string;
};

beforeAll(async () => {
  server = await startTestServer();
});

afterAll(async () => {
  await server.close();
});

function authenticatedRequest(path: string, init?: RequestInit): Request {
  const headers = new Headers(init?.headers);
  headers.set("authorization", `Bearer ${TEST_BEARER_TOKEN}`);
  return new Request(`http://server${path}`, { ...init, headers });
}

function createEntry(entry: EntryJson): Promise<Response> {
  return Promise.resolve(
    server.fetch(
      authenticatedRequest("/entries", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(entry),
      }),
    ),
  );
}

function listEntries(from: string, to: string): Promise<Response> {
  const query = new URLSearchParams({ from, to });
  return Promise.resolve(server.fetch(authenticatedRequest(`/entries?${query}`)));
}

test("an Entry can be read back in a range containing its Eaten At", async () => {
  const entry = {
    id: "e8e45d48-fbbd-48ba-82f7-57b283ba6f12",
    text: "  two eggs, toast, black coffee  ",
    eatenAt: "2026-08-02T08:15:00.000Z",
  };

  const createResponse = await createEntry(entry);
  const listResponse = await listEntries(
    "2026-08-02T08:00:00.000Z",
    "2026-08-02T09:00:00.000Z",
  );

  expect({
    createStatus: createResponse.status,
    created: await createResponse.json(),
    listStatus: listResponse.status,
    listed: await listResponse.json(),
  }).toEqual({
    createStatus: 201,
    created: entry,
    listStatus: 200,
    listed: [entry],
  });
});

test("creating the same Entry identifier twice succeeds and stores one Entry", async () => {
  const entry = {
    id: "52dfb4b9-c835-41b0-aa5e-7271715742ea",
    text: "lentil soup",
    eatenAt: "2026-08-02T12:30:00.000Z",
  };
  const create = () => createEntry(entry);

  const firstResponse = await create();
  const secondResponse = await create();
  const listResponse = await listEntries(
    "2026-08-02T12:00:00.000Z",
    "2026-08-02T13:00:00.000Z",
  );

  expect({
    firstStatus: firstResponse.status,
    secondStatus: secondResponse.status,
    listed: await listResponse.json(),
  }).toEqual({
    firstStatus: 201,
    secondStatus: 200,
    listed: [entry],
  });
});

test("an Entry on the lower range bound is included and one on the upper bound is not", async () => {
  const lower = {
    id: "65568540-84b0-401a-8746-56e30d85e80f",
    text: "lower bound",
    eatenAt: "2026-08-03T08:00:00.000Z",
  };
  const inside = {
    id: "9cd7a228-4989-43bb-8470-b256a854bb9e",
    text: "inside range",
    eatenAt: "2026-08-03T08:30:00.000Z",
  };
  const upper = {
    id: "281f0e89-28f3-4979-a8dc-e0271a0a9c08",
    text: "upper bound",
    eatenAt: "2026-08-03T09:00:00.000Z",
  };

  for (const entry of [lower, inside, upper]) {
    await createEntry(entry);
  }
  const response = await listEntries(
    "2026-08-03T08:00:00.000Z",
    "2026-08-03T09:00:00.000Z",
  );

  expect(await response.json()).toEqual([lower, inside]);
});

test("Entries are listed by Eaten At ascending rather than creation order", async () => {
  const earlier = {
    id: "1e6f01c6-2a30-4850-a761-8ad76d5a2dbf",
    text: "earlier",
    eatenAt: "2026-08-04T12:15:00.000Z",
  };
  const later = {
    id: "66a22d15-2a11-42d3-b7c0-bd9bdaf0f875",
    text: "later",
    eatenAt: "2026-08-04T12:45:00.000Z",
  };

  for (const entry of [later, earlier]) {
    await createEntry(entry);
  }
  const response = await listEntries(
    "2026-08-04T12:00:00.000Z",
    "2026-08-04T13:00:00.000Z",
  );

  expect(await response.json()).toEqual([earlier, later]);
});

test("empty, whitespace-only, and over-length text is rejected without storing an Entry", async () => {
  const invalidEntries = [
    {
      id: "01a8ee1c-f446-4b56-bebd-4e0e19895545",
      text: "",
      eatenAt: "2026-08-05T10:00:00.000Z",
    },
    {
      id: "79cdbd79-22c9-457a-b6fc-60806676aa88",
      text: " \t\n ",
      eatenAt: "2026-08-05T11:00:00.000Z",
    },
    {
      id: "471a23c9-9eb5-4d7b-a0b7-e5f43490447f",
      text: "a".repeat(10_001),
      eatenAt: "2026-08-05T12:00:00.000Z",
    },
    {
      id: "981d3a75-69a6-499c-8d05-463c5a42f2ea",
      text: "offset-less Eaten At",
      eatenAt: "2026-08-05T13:00:00",
    },
    {
      id: "1b62e863-8f16-498c-80a8-e43b7ecdc662",
      text: "impossible Eaten At",
      eatenAt: "2026-02-30T13:00:00Z",
    },
  ];

  const responses = [];
  for (const entry of invalidEntries) {
    responses.push(await createEntry(entry));
  }
  const listResponse = await listEntries(
    "2026-08-05T00:00:00.000Z",
    "2026-08-06T00:00:00.000Z",
  );

  expect({
    createStatuses: responses.map((response) => response.status),
    listed: await listResponse.json(),
  }).toEqual({
    createStatuses: [400, 400, 400, 400, 400],
    listed: [],
  });
});

test("listing rejects missing, malformed, and offset-less range bounds", async () => {
  const requests = [
    authenticatedRequest("/entries?to=2026-08-06T01%3A00%3A00.000Z"),
    authenticatedRequest(
      "/entries?from=not-an-instant&to=2026-08-06T01%3A00%3A00.000Z",
    ),
    authenticatedRequest(
      "/entries?from=2026-08-06T00%3A00%3A00&to=2026-08-06T01%3A00%3A00.000Z",
    ),
    authenticatedRequest(
      "/entries?from=2026-02-30T00%3A00%3A00Z&to=2026-03-03T00%3A00%3A00Z",
    ),
  ];

  const responses = await Promise.all(requests.map((request) => server.fetch(request)));

  expect(responses.map((response) => response.status)).toEqual([400, 400, 400, 400]);
});
