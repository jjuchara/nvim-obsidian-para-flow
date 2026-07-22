# nvim-obsidian-para-flow

`nvim-obsidian-para-flow` is a Neovim plugin for capturing notes into an Obsidian Inbox
and processing that Inbox into a configurable PARA structure through the official Obsidian
CLI.

The current implementation includes configuration, diagnostics, terminal-first Inbox capture,
and the foundation for Inbox review: metadata loading, FIFO ordering, PARA normalization,
reversible operation plans, and a window-independent review session state machine. Inbox review
now opens the oldest note as an editable Markdown buffer in either a centered float or a dedicated
fullscreen tab and keeps the planned actions visible. The actions themselves and PARA sorting are
partially implemented: `e`, `s`, and `q` are active, while PARA sorting and delete remain later
MVP slices.

## Requirements

- Neovim 0.10 or newer (CI covers 0.10, 0.11, and 0.12).
- Obsidian installed with the 1.12.7 or newer installer.
- Obsidian CLI enabled and a running Obsidian desktop application.
- QuickAdd 2.12 or newer with a configured Inbox choice whose filename format and template use
  the named `{{VALUE:title}}` variable.

There are no mandatory Neovim runtime dependencies. `mini.test`, Selene, and StyLua are
development-only tools.

## Setup

All vault-specific paths are mandatory. No personal vault structure is assumed.

```lua
require("obsidian-para-flow").setup({
  -- Must exactly match the vault name available to Obsidian CLI.
  vault = "My Vault",
  inbox = {
    folder = "6. Inbox",
    quickadd_choice = "inbox",
  },
  para = {
    projects = { folder = "1. Projects", link = "[[My Projects]]" },
    areas = { folder = "2. Areas", link = "[[My Areas]]" },
    resources = { folder = "3. Resources" },
    archives = { folder = "4. Archives" },
  },
})
```

Default mappings are `<leader>on` for a new Inbox note and `<leader>oi` for Inbox review.
Set either mapping to `false` to disable it or to another key sequence to replace it.
When WhichKey is available, the default `<leader>o` prefix is labeled `obsidian para flow` and
shown with a purple crystal icon.

## Public API

- `setup(options)` validates and stores configuration and installs mappings.
- `inbox_new()` prompts for the title through `vim.ui.input()`, passes it to the configured
  QuickAdd choice without enabling Obsidian UI, identifies the one newly created Inbox Markdown
  file, opens it in the current window, and positions the cursor at the body.
- `inbox_review()` loads the FIFO Inbox queue and opens the oldest note in the configured review
  layout. The footer exposes all review keys; `e`, `s`, and `q` are currently active.
- `health()` runs read-only dependency and vault diagnostics.

Commands: `:ObsidianParaInboxNew`, `:ObsidianParaInboxReview`, and `:ObsidianParaHealth`.
See `:help obsidian-para-flow` for the built-in manual.

If Obsidian is not running, the first command opens the configured vault through an Obsidian
URI, waits up to 15 seconds for the CLI to become ready, and retries the original command. The
plugin verifies the exact vault name before running QuickAdd and fails closed if Obsidian opens
another vault. An empty or unsafe title, cancellation, or an existing Inbox filename stops the
flow before QuickAdd runs.

## Development

There is no build step. See [CONTRIBUTING.md](CONTRIBUTING.md) for setup and verification.
Architecture and durable decisions are recorded in [ARCHITECTURE.md](ARCHITECTURE.md) and
[DECISIONS.md](DECISIONS.md).

The internal Inbox model reads each Markdown path, its properties, and its CLI-reported creation
time. A valid `created` property takes precedence over file creation time; ties use the
vault-relative path. Metadata normalization preserves existing values, unions required tags, and
builds explicit apply and compensation steps before later review code performs any mutation.
The review session owns the in-memory queue, current note, per-session skipped set, action
counters, pause state, and terminal emergency state without depending on Neovim windows.
The review UI uses the same status, body, and footer regions in both layouts. The body is the real
listed, editable Markdown buffer for the current vault file; the status shows its FIFO position
and path, and the footer remains visible with `p/a/r/x/d/e/s/q`. Float dimensions accept the
configured fractional or exact sizes; fullscreen review is isolated in a dedicated tab. Closing
either layout restores the originating window when it is still valid.

Before `e` or `s` writes an edited note, review compares the file's current size and high-resolution
modification time with the snapshot captured when the buffer was loaded. An external change or a
Neovim write failure cancels the action and leaves the current note open. `e` saves, pauses the
session, and opens the note in the originating window. `s` saves, skips the note for the current
pass, and advances to the next FIFO item. When the pass ends, review reports processed, skipped,
and remaining Inbox counts without claiming a skipped Inbox is empty.

`q` closes an unchanged review immediately. For unsaved changes it offers `Cancel`, `Save and
exit`, and `Discard and exit`, with the safe cancellation first. Saving uses the same external
change guard; discarding reloads the real file before closing. `p`, `a`, `r`, `x`, and `d` remain
visible but inactive until their transaction slices are implemented.

For manual testing with the existing LazyVim profile, run `./scripts/nvim-dev`. It prepares a
persistent isolated vault under the XDG state directory and loads this working tree through
`.lazy.lua`. See [CONTRIBUTING.md](CONTRIBUTING.md) for first-time vault registration, QuickAdd
bootstrap, fixture reset, and safety details.
