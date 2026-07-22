# Contributing

## Verification

Install Neovim 0.10+, StyLua, Selene, and make `mini.nvim` available at
`.deps/mini.nvim` (a symlink to an existing checkout is sufficient).

- `make test` runs isolated headless tests with `mini.test`.
- `make lint` runs Selene and checks StyLua formatting.
- `make format` formats Lua sources and tests.
- `make check` is the complete local automated gate.
- `make helptags` regenerates `doc/tags` after Vim help changes.
- `make test-integration TEST_VAULT=<name>` is an explicit vault integration gate.

The integration target refuses to run without `TEST_VAULT`. Automated tests replace the CLI
executor and never access a real vault.

## Change discipline

Keep runtime code dependency-free and route every Obsidian CLI invocation through
`lua/obsidian-para-flow/cli.lua`. Add automated coverage for behavior, update `CHANGELOG.md`
for user-visible changes, and record durable architectural decisions in `DECISIONS.md`.

## Manual testing with LazyVim

Prepare and start an isolated development profile:

```sh
./scripts/nvim-dev
```

The launcher follows the same local-spec pattern as the neighboring `obsidian-tasks.nvim`
plugin. It creates a persistent test vault at
`$XDG_STATE_HOME/nvim-obsidian-para-flow-dev` (or
`~/.local/state/nvim-obsidian-para-flow-dev`), exports a dev-only profile, and lets Lazy.nvim's
project-local `.lazy.lua` load this checkout with fixture configuration. Normal Neovim launches
continue to use the installed plugin and production configuration.

On first launch, inspect `.lazy.lua` when Neovim prompts and run `:trust`. Trust is stored per
`NVIM_APPNAME`, so it must be granted to the `LazyVim` profile used by the launcher.

Obsidian currently cannot register an arbitrary folder as a vault through its public CLI. On
the first run, open Obsidian's vault switcher, choose **Open folder as vault**, and select the
path printed by the launcher. This is a one-time registration step. The directory name and the
configured vault name must match.

The fixture includes the QuickAdd `inbox` choice and template configuration. Supply an existing
QuickAdd installation when preparing the vault to copy only its runtime files while preserving
the fixture settings:

```sh
OBSIDIAN_PARA_QUICKADD_DIR=/path/to/vault/.obsidian/plugins/quickadd \
  ./scripts/nvim-dev --prepare
```

Alternatively, install and enable QuickAdd in the test vault through Obsidian. Community plugin
trust may require one confirmation on first open. Run `./scripts/nvim-dev --reset` to move the
current test vault to a timestamped backup and recreate a clean fixture. Never register or use a
production vault as the development vault when testing write operations.
