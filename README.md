# Food Guide

A personal food log. You type what you ate in plain language, it gets saved, and you can see
today's **Entries**. Nothing counts calories, parses your text, or offers advice — the point is to
make recording a meal fast enough that the habit survives, and to make the record durable enough
to trust months later.

An iOS app and its backend, in one repository.

**Status: the backend skeleton exists; the app does not.** The work is tracked in the issues.

## Where the thinking lives

- **[`CONTEXT.md`](./CONTEXT.md)** — the domain glossary. The vocabulary used in code, tests,
  commits, and issues. An Entry is not a "meal".
- **[`docs/adr/`](./docs/adr)** — architectural decisions, including two prohibitions that a
  reader would otherwise be tempted to "fix": the server has no concept of a day, and the app's
  dependencies are closure structs rather than protocols.
- **[Issue #1](https://github.com/OpenTile/food-guide/issues/1)** — the spec. Its sub-issues are
  the build tickets, each declaring what blocks it.
- **[`AGENTS.md`](./AGENTS.md)** — how AI agents should work in this repository.

## Deliberately out of scope

Calories and macros, food databases, meal types, photos, viewing any day but today, editing an
Entry, offline capability, search, export, and multi-user anything. These are exclusions, not
omissions — see the spec for why.

## Licence

MIT. See [`LICENSE`](./LICENSE).
