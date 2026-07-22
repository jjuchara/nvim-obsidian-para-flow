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
