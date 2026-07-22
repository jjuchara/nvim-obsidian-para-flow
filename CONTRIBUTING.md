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

The integration target refuses to run without `TEST_VAULT`. It verifies the exact open vault,
creates one uniquely named and frontmatter-marked fixture without overwrite, moves it from Inbox
to Archives, verifies its content, and sends it to the vault trash. It attempts cleanup after a
failed assertion. The default folders are `6. Inbox` and `4. Archives`; override them with
`OBSIDIAN_PARA_TEST_INBOX` and `OBSIDIAN_PARA_TEST_ARCHIVES` for a disposable vault with another
layout. Never use a production vault. Isolated automated tests replace the CLI executor and never
access any vault.

Use [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md) to record the CI, integration, stock/third-party
UI, rollback, and manual end-to-end evidence required before a stable release.
[MANUAL_TESTING.md](MANUAL_TESTING.md) provides the exact disposable-vault procedure and the
test-only CLI fault proxy used to reproduce move and merge rollback safely.

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

For the capture smoke test, invoke `<leader>on`, enter the title in Neovim, and verify that no
QuickAdd prompt opens in Obsidian. The new fixture note must open in the current Neovim window
with the cursor below its H1.
