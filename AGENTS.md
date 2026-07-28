# AGENTS.md

Guidance for AI agents working in this repo. This is the canonical instructions file — add all future agent guidance here directly.

## The server

TypeScript on Bun in `server/`. Requires **Bun 1.3 or newer** — on earlier versions the test
container never finishes starting.

```sh
cd server
bun install
bun test           # Seam A, against a real Postgres
bun run typecheck
bun run dev        # needs DATABASE_URL — copy .env.example to .env
```

### Container runtime for the tests

Seam A runs against a real Postgres started by testcontainers, so **a Docker-compatible daemon
must be running** or every test fails at startup. Any of colima, OrbStack, Rancher Desktop or
Docker Desktop works; this project is developed against [colima](https://github.com/abiosoft/colima)
(`colima start`).

`test/setup.ts` resolves the daemon from the Docker CLI's active context and points the reaper at
the in-VM socket path, so no `DOCKER_HOST` export is needed. Two failures worth recognising:

- `Could not find a working container runtime strategy` — no daemon is running.
- `colima start` reporting `vz driver is running but host agent is not` — the VM is in a stale
  state; `colima stop --force` followed by `colima start` clears it.

## Agent skills

### Issue tracker

Issues live in the `OpenTile/food-guide` GitHub Issues, managed with the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Default canonical labels (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `CONTEXT.md` + `docs/adr/` at the repo root. See `docs/agents/domain.md`.
