# nvim-obsidian-para-flow

`nvim-obsidian-para-flow` is a Neovim plugin for capturing notes into an Obsidian Inbox
and processing that Inbox into a configurable PARA structure through the official Obsidian
CLI.

The current implementation includes configuration, diagnostics, terminal-first Inbox capture,
and the domain foundation for Inbox review: metadata loading, FIFO ordering, PARA normalization,
and reversible operation plans. The review UI and execution of PARA sorting are planned but are
not implemented yet.

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
The review mapping currently reports that the later MVP slice is not implemented. Set either
mapping to `false` to disable it or to another key sequence to replace it.
When WhichKey is available, the default `<leader>o` prefix is labeled `obsidian para flow` and
shown with a purple crystal icon.

## Public API

- `setup(options)` validates and stores configuration and installs mappings.
- `inbox_new()` prompts for the title through `vim.ui.input()`, passes it to the configured
  QuickAdd choice without enabling Obsidian UI, identifies the one newly created Inbox Markdown
  file, opens it in the current window, and positions the cursor at the body.
- `inbox_review()` is reserved for the review vertical slice.
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

For manual testing with the existing LazyVim profile, run `./scripts/nvim-dev`. It prepares a
persistent isolated vault under the XDG state directory and loads this working tree through
`.lazy.lua`. See [CONTRIBUTING.md](CONTRIBUTING.md) for first-time vault registration, QuickAdd
bootstrap, fixture reset, and safety details.
