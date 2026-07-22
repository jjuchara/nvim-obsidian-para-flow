# Architecture

## Boundaries

The plugin exposes only `setup`, `inbox_new`, `inbox_review`, and `health` as stable Lua API.
Commands are stable as documented in `README.md`; internal modules are not.

Dependencies point inward as follows:

```text
plugin entry -> public init -> config
                          -> inbox -> cli
                          -> review -> ui, cli, metadata
                          -> health -> cli
```

`cli` is the only process boundary. It passes argv arrays to `vim.system()` and never builds a
shell command. Tests replace its executor. `config`, `metadata`, and path/cursor helpers remain
pure where possible.

## First vertical slice

QuickAdd 2.12 provides `quickadd choice=<name> ui` and returns a JSON execution result, but that
result does not identify the created file. The `ui` flag allows the configured choice to collect
its interactive inputs. Inbox creation therefore uses this read-mutate-read
protocol:

1. list Markdown paths under the configured Inbox;
2. execute the configured QuickAdd choice in the configured vault;
3. list the Inbox again and calculate newly added paths;
4. continue only when exactly one new Markdown file is inside the Inbox;
5. query the vault root, open that file, and position the cursor after frontmatter and the first
   H1.

Zero results, multiple results, cancellation, malformed CLI output, and CLI failures are safe
errors: no unrelated file is opened.

When the CLI reports that Obsidian is unavailable, the adapter opens an
`obsidian://open?vault=...` URI, polls CLI readiness for at most 15 seconds, and retries the
original argv once. Launching is part of the process boundary and is injectable in tests. Inbox
creation verifies `vault info=name` before its first snapshot so an unresolved vault selector
cannot fall through to another open vault.

## Development environment

`scripts/nvim-dev` creates a persistent isolated fixture vault in XDG state. `.lazy.lua` is
active only under `OBSIDIAN_PARA_PROFILE=dev`; it points Lazy.nvim at the current checkout and
injects the fixture vault configuration. Reset moves the old vault to a timestamped backup
before recreating it. Obsidian vault registration remains a one-time UI step because the public
CLI cannot register an arbitrary folder as a vault.

## Supported versions and dependencies

Neovim 0.10 is the compatibility floor; CI tests 0.10, 0.11, and 0.12. Obsidian must use the
1.12.7+ installer with CLI enabled, and QuickAdd must be 2.12+. Runtime has no third-party
Neovim dependency. Development uses mini.test, Selene, and StyLua.
