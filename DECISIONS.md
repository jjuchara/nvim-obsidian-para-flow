# Decision Log

## 2026-07-22 — Keep the runtime dependency-free

Accepted. Neovim 0.10+ and the official Obsidian CLI are the runtime boundary. mini.test,
Selene, and StyLua remain development-only dependencies.

## 2026-07-22 — Require all vault structure explicitly

Accepted. `vault`, Inbox folder and QuickAdd choice, PARA folders, and Projects/Areas MOC links
are mandatory. The plugin does not silently assume a personal vault layout.

## 2026-07-22 — Use one asynchronous CLI adapter

Accepted. Only `cli.lua` may invoke Obsidian. It uses `vim.system()` with argv arrays, a timeout,
normalized results, and an injectable executor for isolated tests.

## 2026-07-22 — Discover QuickAdd output by an Inbox snapshot diff

Accepted. QuickAdd 2.12 CLI JSON confirms execution but does not return the created path. The
plugin compares Inbox Markdown paths before and after execution and opens a file only when the
difference contains exactly one safe path under the configured Inbox folder.

## 2026-07-22 — Isolate manual testing in an XDG-state vault

Accepted. `scripts/nvim-dev` prepares a persistent fixture vault outside the repository and
activates `.lazy.lua` only for the dev process. Reset preserves the previous vault as a
timestamped backup. Registration through the Obsidian vault switcher is a one-time manual step
until the public CLI supports registering arbitrary folders.

## 2026-07-22 — Start Obsidian on the first unavailable CLI call

Accepted. An unavailable CLI response opens the configured vault via Obsidian URI, waits up to
15 seconds for readiness, and retries the original argv once. Launch and scheduling boundaries
are injectable for tests. Mutating Inbox flow verifies the exact vault name before QuickAdd and
fails closed on a mismatch.
