# Changelog

## Unreleased

### Added

- Initial plugin skeleton, development tooling, isolated test harness, and Neovim CI matrix.
- Validated vault-specific configuration with configurable mappings and review layout.
- Stable Lua API and user commands for Inbox creation, review, and health diagnostics.
- Central asynchronous Obsidian CLI adapter with normalized error categories and safe argv use.
- Read-only health checks for Neovim, Obsidian CLI, vault identity, QuickAdd choice, and folders.
- QuickAdd Inbox creation with before/after path discovery and safe cursor positioning.
- Isolated LazyVim development launcher with a persistent fixture vault and recoverable reset.
- Automatic Obsidian startup, bounded readiness polling, and one retry of the original command.
- Exact vault identity verification before QuickAdd to prevent fallback to another open vault.
- Built-in `:help obsidian-para-flow` documentation and generated help tags.
- Inbox domain loading with safe path validation, properties, CLI file creation timestamps, and
  deterministic FIFO ordering.
- Pure PARA metadata normalization and reversible operation plans for the upcoming review
  transaction layer.
- Window-independent review session state with FIFO advancement, per-pass skips, counters,
  pause semantics, and a terminal emergency state.
- Shared status, body, and footer review layout with centered configurable float and isolated
  fullscreen-tab variants.
- FIFO Inbox review startup that loads the oldest vault note into a listed, editable Markdown
  buffer and keeps its queue position, path, and planned action keys visible.

### Changed

- `<leader>on` now collects the Inbox title in Neovim and runs QuickAdd non-interactively, keeping
  the complete capture flow in the terminal.
- WhichKey now labels the default `<leader>o` mapping group as `obsidian para flow` when the
  optional WhichKey plugin is available and displays it with a purple crystal icon.
