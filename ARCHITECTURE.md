# Architecture

## Boundaries

The plugin exposes only `setup`, `inbox_new`, `inbox_review`, and `health` as stable Lua API.
Commands are stable as documented in `README.md`; internal modules are not.

Dependencies point inward as follows:

```text
plugin entry -> public init -> config
                          -> inbox -> cli
                          -> review -> ui, cli, metadata, sorting, transaction,
                                      conflict, merge_transaction
                                             sorting -> ui, cli
                                         transaction -> cli
                          merge_transaction -> cli
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
and reverse compensation steps.

`sorting` owns the read-only interaction and preflight phase. It lists the category root and safe
nested folders through the CLI, collects a missing `area` from `tag:#area` search results or a
missing archive reason, verifies the source and destination folder, and rejects an exact target
path conflict before allowing the first mutation. `transaction` executes an immutable plan by
setting properties in order and moving last. Any property or move failure compensates applied
steps in reverse order. Complete rollback returns control to the current note; incomplete rollback
returns structured recovery details and forces the review session into its terminal halted state.

## Conflict resolution and merge

An exact target path returned by sorting preflight enters a temporary mode inside the existing
review view. `ui` changes the single body region into labeled, read-only target and Inbox panes
without replacing the review session or current note. The controller owns local `m/r/d/q` and
`<Tab>` mappings and restores the original editable Inbox body and review mappings on exit.

`conflict` is the pure merge-draft boundary. It validates final filenames, combines target-first
metadata, unions tags, applies the existing PARA normalization rules, strips frontmatter from both
bodies, and removes the first Inbox H1 only when it exactly matches the first target H1. The draft
is deterministic YAML plus target body, a Markdown separator, and Inbox body.

Merge Preview replaces the comparison panes with an editable scratch Markdown buffer. Before
commit, the controller re-reads both notes and requires exact equality with the snapshots used to
build the preview. `merge_transaction` writes the target through the CLI, trashes the Inbox source
last, and restores the original target after either failure. An unsuccessful restore is a terminal
session emergency with the known state of both paths.

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
The default `0.7 × 0.7` layout places them inside one centered, titled float frame occupying 70% of
the available editor width and height. Its content is
inset horizontally, status and command bar use a second neutral surface, and the editable Markdown
body remains dominant. Configured fractional dimensions resolve against the available editor area;
whole values remain exact within that area. Fullscreen layout creates a dedicated tab with one-line
status and footer splits.

The review controller resolves the vault root after loading the FIFO queue, loads the current
vault file into a listed editable Markdown buffer, and injects that buffer into the layout. The
status derives its position and path from the session snapshot, while the footer permanently
shows the planned `p/a/r/x/d/e/s/q` actions. The view owns only a body buffer it creates itself;
the controller-owned file buffer survives layout closure. Closing is idempotent, removes the
layout windows or tab, and restores the originating window when possible.

Float windows receive dedicated, theme-derived highlight groups. Their surface follows `Pmenu`,
the theme's native popup role, then falls back through `NormalFloat`, `ColorColumn`, and `Normal`.
The shared configurable `winblend` defaults to `0`, preventing lower-buffer text from competing
with Markdown; users can opt into blending explicitly. Frame, chrome, body, and temporary conflict
panes share the same surface contract. Fullscreen uses the user's ordinary window highlights. The
border title identifies review, conflict, preview, and halted modes.

The controller records a size and high-resolution modification-time fingerprint when it loads a
note. Saving actions compare that fingerprint immediately before a normal Neovim buffer write;
an external change or write failure leaves the session and current buffer in place. Skip advances
only after a successful guard and save. Perform-now pauses the session before closing the layout
and placing the saved buffer in the originating window. Quit closes unchanged buffers directly;
modified buffers require an explicit save or discard choice, with cancellation first.
Buffer-local action mappings are installed only while a note is hosted by review and are removed
before a note is advanced, handed back to the originating window, or closed.

Delete uses the same guarded save path before prompting through `vim.ui.select()`. The safe
`Cancel` choice is first. Only explicit confirmation calls the Obsidian CLI trash operation, and
the session records completion and advances only after a successful CLI result. Cancellation or
failure keeps the current note and queue position intact. Review ignores additional actions while
confirmation or the asynchronous trash request is pending. Permanent deletion is not supported.

## First vertical slice

QuickAdd 2.12 accepts variables on `quickadd choice=<name>` and returns a JSON execution result,
but that result does not identify the created file. Inbox creation collects `title` through
Neovim's `vim.ui.input()` and passes the same validated text as both `value-title=<title>` and
`value-value=<title>` without the `ui` flag. The named value renders the configured
`{{VALUE:title}}` placeholders; the reserved `value` also satisfies the Template choice's default
filename input in QuickAdd 2.12.3. The interactive flow therefore stays in the terminal. The
configured choice must use `{{VALUE:title}}` for its filename format and template. Creation uses
this read-mutate-read protocol:

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

The opt-in integration boundary uses the same `cli` adapter as runtime code. It first proves the
CLI resolved the explicitly supplied vault name, then operates on a high-entropy filename prefixed
with `__obsidian-para-flow-integration-` and content marked by
`obsidian_para_flow_fixture: true`. Creation omits the CLI overwrite flag. The fixture is verified
before and after its Inbox-to-Archives move and is finally sent to the vault trash; a failed run
attempts cleanup at both known paths. This gate is intentionally separate from isolated tests and
from the manual UI and rollback checklist.

Manual rollback verification launches the normal development profile with
`tests/manual/bin/obsidian` first on `PATH`. The proxy requires the absolute real CLI path and
forwards all argv unchanged except one explicitly selected test fault: every move, or trash of the
fixed `__opf-manual-merge-rollback.md` Inbox source. Runtime code has no fault-injection branch.

## Supported versions and dependencies

Neovim 0.10 is the compatibility floor; CI tests 0.10, 0.11, and 0.12. Obsidian must use the
1.12.7+ installer with CLI enabled, and QuickAdd must be 2.12+. Runtime has no third-party
Neovim dependency. When WhichKey is already available, `setup()` registers a display-only group
for the default `<leader>o` prefix through its v3 `add()` API. Development uses mini.test, Selene,
and StyLua.
