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

## Inbox domain model

`inbox.load()` lists Markdown files under the configured Inbox, rejects paths outside that
boundary, and retrieves each file's properties and CLI file information. Obsidian reports file
timestamps as Unix milliseconds; the model stores seconds. Notes are ordered by a valid
frontmatter `created` value, then by file creation time when that value is missing or invalid,
and finally by vault-relative path for deterministic ties.

`metadata` accepts `DD.MM.YYYY HH:mm` and ISO date/datetime values. Values without an explicit
timezone use local time; explicit offsets are converted without depending on the process
timezone. PARA normalization is pure and add-missing: existing properties and body content are
not overwritten, while required tags are unioned. The resulting operation plan contains
preflight requirements, the original metadata snapshot, ordered property steps, the final move,
and reverse compensation steps. Later transaction code executes that plan through `cli`.

## Review session

`session` is independent of Neovim buffers and windows. It receives the already ordered Inbox
notes and owns the current pass: the remaining queue, current note, processed and skipped counts,
per-action counts, and skipped paths. Completing or skipping a note advances exactly once.
Skipped paths leave only the current pass and therefore prevent a finished session from claiming
that the Inbox was fully processed.

A session is `active`, `finished`, `paused`, or `halted`. Pause preserves the current note for
flows such as perform-now or exit. Halt is terminal for that session and preserves both the
current note and structured emergency details so later transaction code cannot advance after an
incomplete rollback. The UI consumes immutable snapshots rather than owning review state.

## Review layout

`ui.open_review()` renders the same status, body, and footer buffers in both supported layouts.
The default layout places them inside one centered bordered float frame; configured fractional
dimensions are resolved against the available editor area and whole values remain exact within
that area. Fullscreen layout creates a dedicated tab with one-line status and footer splits.

The review controller resolves the vault root after loading the FIFO queue, loads the current
vault file into a listed editable Markdown buffer, and injects that buffer into the layout. The
status derives its position and path from the session snapshot, while the footer permanently
shows the planned `p/a/r/x/d/e/s/q` actions. The view owns only a body buffer it creates itself;
the controller-owned file buffer survives layout closure. Closing is idempotent, removes the
layout windows or tab, and restores the originating window when possible.

The controller records a size and high-resolution modification-time fingerprint when it loads a
note. Saving actions compare that fingerprint immediately before a normal Neovim buffer write;
an external change or write failure leaves the session and current buffer in place. Skip advances
only after a successful guard and save. Perform-now pauses the session before closing the layout
and placing the saved buffer in the originating window. Quit closes unchanged buffers directly;
modified buffers require an explicit save or discard choice, with cancellation first.
Buffer-local action mappings are installed only while a note is hosted by review and are removed
before a note is advanced, handed back to the originating window, or closed.

## First vertical slice

QuickAdd 2.12 accepts named variables on `quickadd choice=<name>` and returns a JSON execution
result, but that result does not identify the created file. Inbox creation collects `title`
through Neovim's `vim.ui.input()` and passes `value-title=<title>` without the `ui` flag, so the
interactive flow stays in the terminal. The configured choice must use `{{VALUE:title}}` for its
filename format and template. Creation uses this read-mutate-read protocol:

1. collect and validate the title in Neovim;
2. list Markdown paths under the configured Inbox and reject an existing target filename;
3. execute the configured QuickAdd choice non-interactively in the configured vault;
4. list the Inbox again and calculate newly added paths;
5. continue only when exactly one new Markdown file is inside the Inbox;
6. query the vault root, open that file, and position the cursor after frontmatter and the first
   H1.

Invalid input, name collisions, zero results, multiple results, malformed CLI output, and CLI
failures are safe errors: no unrelated file is opened.

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
Neovim dependency. When WhichKey is already available, `setup()` registers a display-only group
for the default `<leader>o` prefix through its v3 `add()` API. Development uses mini.test, Selene,
and StyLua.
