# Decision Log

## 2026-07-22 — Delete reviewed notes only through Obsidian trash

Accepted. The `d` action uses the common external-change guard and saves the current buffer before
showing a confirmation through `vim.ui.select()`, with `Cancel` as the first choice. Explicit
confirmation invokes only the Obsidian CLI delete operation, which follows the vault's configured
trash behavior. The session advances only after success; cancellation or failure leaves the current
note and queue unchanged. Additional review actions are ignored while confirmation or the trash
request is pending. Permanent deletion is outside the MVP.

## 2026-07-22 — Share one review layout model across float and fullscreen

Accepted. Both layouts render the same status, editable body, and footer buffer roles. The float
uses a centered bordered frame and configured fractional or exact dimensions. Fullscreen review
uses a dedicated tab so its splits do not replace the user's current layout. The body buffer is
injectable and remains owned by its caller; closing the review restores the originating window
when it still exists.

## 2026-07-22 — Keep review session state independent of Neovim windows

Accepted. The review session owns the ordered queue, current note, per-session skipped paths,
processed and action counters, and its lifecycle without opening or inspecting windows. Pause
keeps the current note available for perform-now and exit flows. A transaction emergency moves
the session to a terminal halted state with structured details, preventing accidental queue
advancement. UI code renders immutable session snapshots and does not become the source of truth.

## 2026-07-22 — Build review mutations from a pure operation plan

Accepted. Inbox loading obtains properties and file creation timestamps through the official CLI,
then orders notes without touching the vault. PARA normalization produces add-missing property
steps plus reverse compensation steps from an immutable snapshot. Review and transaction code
must collect every missing input and complete preflight before executing this plan through the CLI.

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

## 2026-07-22 — Collect Inbox titles in Neovim

Accepted. `<leader>on` collects the note title through `vim.ui.input()` and passes it to QuickAdd
as the named `title` variable. QuickAdd runs without its `ui` flag, so interactive capture stays
inside the terminal while template rendering and file creation remain behind the Obsidian CLI
boundary. The plugin rejects invalid or colliding filenames before mutation and retains the
before/after Inbox snapshot check as the final path-discovery guard.

## 2026-07-22 — Label the optional WhichKey group

Accepted. When WhichKey is available and a configured mapping uses the default `<leader>o`
prefix, the plugin registers `obsidian para flow` as that prefix's display group through
`which-key.add()` and gives it a portable purple crystal icon. This integration creates no
keymap and does not make WhichKey a runtime dependency.
