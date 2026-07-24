# Decision Log

## 2026-07-24 — Keep note rename local, explicit, and shared across navigation surfaces

Accepted, implemented, and released in `v0.7.0`. `c` in Home and `<C-r>` in supported search backends rename exactly the
selected note without moving it to another folder or rewriting its H1. One shared boundary accepts
the basename with or without `.md`, rejects empty names, path separators, control characters,
modified Neovim buffers, and an existing destination before calling the official Obsidian CLI.
Home refreshes after success and search reopens its current surface. Entering a new name is the
explicit commit step; unlike trash, rename does not require a second confirmation.

Merge selection is a task UI rather than Markdown content. Its scratch buffer therefore uses a
plugin-specific filetype and a candidate-sized float so Markdown checkbox renderers cannot alter
`[x]` markers or create an oversized empty surface. Only the editable preview switches to Markdown
and expands to the configured review dimensions.

## 2026-07-24 — Merge semantic duplicates only after explicit multi-selection

Accepted and implemented. `m` in Home and `<C-o>` in supported search pickers start one plugin-owned
selection flow from the current visible result set. `Space` records two or more notes in user order;
the next step explicitly chooses the path to keep. The editable preview keeps target metadata first,
fills missing properties from sources, unions tags, strips source frontmatter, and renders every body
under `## <filename>` with `---` separators. `<leader>om` commits and `<leader>oq` cancels.

Commit revalidates every content snapshot and rejects modified Neovim buffers. It writes the target
before trashing sources in order. A failure before any trash restores the target and leaves preview
available; a later partial failure restores the target where possible and reports the exact state of
every source already trashed, failed, or not attempted. Automatic semantic-duplicate detection and
permanent deletion remain out of scope.

## 2026-07-23 — Keep the expanded public surface explicit

Accepted. The stable commands are `:ObsidianParaHome`, `:ObsidianParaFind`,
`:ObsidianParaGrep`, `:ObsidianParaInboxNew`, `:ObsidianParaInboxNewWithTask`,
`:ObsidianParaCapture`, `:ObsidianParaInboxReview`, and `:ObsidianParaHealth`. The stable Lua API is
`setup`, `home`, `inbox_new`, `inbox_new_with_task`, `capture`, `inbox_review`, `find`, `grep`, and
`health`. `grep_prompt` and internal modules remain implementation details.

## 2026-07-23 — Allow one explicit safe mutation from Home and search

Accepted. `d` in the Home overview or any full section, and the corresponding delete action in
every search backend, asks for confirmation and routes the selected vault-relative Markdown path
through the official Obsidian trash command. There is no permanent-delete path. Home keeps its
metadata and body-loading contracts read-only, suppresses duplicate pending actions, and removes a
note only after CLI success; search reopens or refreshes its result surface. This supersedes only
the blanket no-mutation clause in the original Home decision below.

## 2026-07-23 — Preserve the originating repository during vault navigation

Accepted. Opening a note directly or through search from Home closes the temporary Home tab and
opens the note in a new tab. Search invoked outside the vault also changes its default selection to
a new-tab action across every supported picker and the built-in fallback; search invoked from a
vault buffer retains the picker's normal current-tab action. The active buffer path defines the
context, with Neovim's working directory as the fallback for unnamed buffers.

## 2026-07-22 — Release the accepted Home workflow as v0.2.0

Accepted. The project owner verified the implemented Home workflow in real use and approved it for
release. Home is published as `v0.2.0` because it adds a new user-facing workflow to the existing
`v0.1.x` MVP line. The release remains gated by the 112-case isolated suite, the three-case
disposable-vault integration suite, a clean release commit, and green GitHub CI.

## 2026-07-22 — Build Home as a read-only PARA launcher

Accepted and implemented. Home opens in a dedicated tab, loads Inbox and configured PARA roots only
through the official Obsidian CLI, and restores the originating window when it closes. The overview
emphasizes Projects, previews every category, and opens grouped full lists with a metadata-only
details panel. The original originating-window behavior was superseded by the 2026-07-23
repository-preservation decision above. Home never evaluates Dataview or Tasks queries and never
mutates vault metadata. The confirmed trash exception is defined by the 2026-07-23 decision above.
Daily notes, task management, body preview, multiple vaults, and configurable non-PARA categories
remain separate work.

## 2026-07-22 — Keep Home progressive, keyboard-complete, and locally recoverable

Accepted and implemented. Sections load independently with bounded note hydration, local loading or
error states, and a refresh generation that discards stale callbacks. `<leader>oh` opens Home;
`j/k`, Tab, `p/a/r/x`, `/`, Enter, `n`, `i`, `R`, Escape, `?`, and `q` complete the workflow. A
failed section does not hide successful data, and a missing selected file leaves Home open.

## 2026-07-22 — Use a replaceable theme-aware Home background

Accepted and implemented. The default constellation is static, sparse, theme-derived, and rendered
behind dashboard content with an ASCII fallback. Configuration may disable it or replace it with a
callback returning clipped text fragments. A custom provider fully replaces the preset; invalid
output or callback failure degrades to a clean usable background. The dashboard uses one restrained
theme accent with a purple fallback and never communicates state through color alone.

## 2026-07-22 — Close post-release stabilization at the agreed MVP boundary

Accepted. The project owner confirmed that `v0.1.3` works within the previously agreed MVP scope.
The post-release checklist and stabilization roadmap are therefore complete. This acceptance does
not add Home, Daily notes, multiple vault profiles, or configurable non-PARA categories to the
released contract; those remain separate roadmap work.

## 2026-07-22 — Publish the MVP on the semantic-version release channel

Accepted. MVP releases use ordinary `vMAJOR.MINOR.PATCH` tags so Lazy.nvim's `version = "*"`
range can discover them. The GitHub release title identifies the maturity as MVP, while the Git
tag does not use a Semver pre-release suffix because Lazy.nvim excludes those suffixes from `*`.
Users update through `:Lazy update`, which refreshes the selected tag in `lazy-lock.json`.
This channel decision does not weaken the separate evidence gate for declaring the first stable
release complete.

## 2026-07-22 — Give review the hierarchy of a native picker

Accepted. The default float is `0.7 × 0.7`, centered, and occupies 70% of the available editor area.
The active mode appears in the border title; queue and path
occupy one compact status row; actions use a persistent bracketed command bar. Status and footer use
a theme-derived second neutral surface while the real Markdown buffer remains visually dominant.
Fractional and exact custom sizes and fullscreen remain supported.

## 2026-07-22 — Keep float transparency controlled

Accepted. Float frame, status, body, footer, and conflict panes use dedicated highlight groups whose
background follows the active theme's `Pmenu` popup role, then `NormalFloat`, `ColorColumn`, `Normal`,
and finally the editor background mode. A shared configurable `winblend` defaults to `0` because
blending reveals lower-buffer glyphs, not only the terminal background. Users may opt into a higher
value explicitly. Fullscreen keeps the user's ordinary window highlights.

## 2026-07-22 — Gate stable releases on disposable-vault evidence

Accepted. The opt-in integration gate requires an explicit vault name, verifies that exact vault
before mutation, and creates only uniquely named fixtures carrying an explicit frontmatter marker.
Fixture creation never overwrites an existing path; the harness moves and reads the fixture before
sending it to the vault trash and attempts cleanup after failure. Integration success complements,
but does not replace, the recorded manual capture, review, provider, conflict, and rollback checks.
No stable tag may be created while the release checklist's final decision remains incomplete.
That final decision was completed by project-owner acceptance on 2026-07-22 for the agreed
`v0.1.x` MVP boundary.

## 2026-07-22 — Keep conflict resolution inside the active review view

Accepted. An exact destination-path conflict replaces the review body with labeled, read-only
target and Inbox panes while preserving the current session and note. `<Tab>` switches panes and
local `m/r/d/q` mappings remain visible. Exiting restores the same editable Inbox buffer and its
normal review mappings.

## 2026-07-22 — Treat rename as a final move destination

Accepted. Conflict rename accepts a filename with an optional `.md` suffix, rejects empty names,
`.` / `..`, and path separators, and repeats source/folder/conflict preflight. It never performs an
intermediate Inbox rename or changes H1; the normalized name is used only by the final transactional
PARA move. A repeated conflict remains in the resolver without mutation.

## 2026-07-22 — Build merge as an editable neutral document

Accepted. The existing target supplies preferred metadata and the first body. Missing Inbox
properties are retained, tags are unioned, and missing required PARA properties are applied through
the established normalization rules. Inbox frontmatter is not copied into the body. The Inbox body
follows a Markdown `---` separator, and its first H1 is removed only when it exactly matches the
target's first H1. The user may edit the complete preview before confirmation.

## 2026-07-22 — Write the merge target before trashing its Inbox source

Accepted. Merge commit first verifies that target and source still equal the snapshots used for
preview, writes the approved target through Obsidian CLI, and trashes the Inbox source last. Failure
at either mutation restores the original target snapshot and leaves the queue unchanged. A failed
restore halts review and reports the known state of both paths.

## 2026-07-22 — Complete PARA input and preflight before mutation

Accepted. A PARA action lists the category root first and then safe nested folders through the
official `folders` command. Missing Projects/Resources `area` values come from paths returned by a
`tag:#area` search and are stored as vault-qualified wikilinks; a missing Archives reason comes
from `vim.ui.input()`. Cancellation, an invalid value, a missing source or folder, and an exact
destination conflict stop before saving the edited buffer or changing properties. Exact conflicts
are reserved for the Node 8 resolver.

## 2026-07-22 — Halt review after incomplete PARA rollback

Accepted. A PARA transaction reads a fresh metadata snapshot after the guarded buffer save,
applies add-missing property steps in order, and moves the note last. Property and move failures
compensate every completed property step in reverse order. Full compensation leaves the same note
open. Any failed compensation halts the session, disables every action except quit, and reports
the source, destination, changed properties, and each failed recovery step. The queue advances
only after the move succeeds.

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
as both the named `title` variable and the reserved `value` variable. QuickAdd 2.12.3 requires the
latter for a Template choice even when the configured filename and body use `{{VALUE:title}}`.
QuickAdd runs without its `ui` flag, so interactive capture stays inside the terminal while
template rendering and file creation remain behind the Obsidian CLI boundary. The plugin rejects
invalid or colliding filenames before mutation and retains the before/after Inbox snapshot check
as the final path-discovery guard.

## 2026-07-22 — Label the optional WhichKey group

Accepted. When WhichKey is available and a configured mapping uses the default `<leader>o`
prefix, the plugin registers `obsidian para flow` as that prefix's display group through
`which-key.add()` and gives it a portable purple crystal icon. This integration creates no
keymap and does not make WhichKey a runtime dependency.

## 2026-07-22 — Interpret a Templater cursor marker in Neovim

Accepted. QuickAdd creates Inbox notes without opening them in Obsidian, so Templater can leave
the editor-only `<% tp.file.cursor() %>` command in the file even while rendering other template
expressions. Inbox creation consumes the first exact no-argument marker in the opened Neovim
buffer and positions the cursor at its start. Templates without the marker retain the structural
fallback after frontmatter and the first H1. Ordered and multi-cursor Templater markers are not
interpreted.
