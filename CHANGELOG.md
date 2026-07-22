# Changelog

## Unreleased

## 0.3.0 - 2026-07-23

### Fixed

- Fixed Home filtering for non-ASCII notes. Case folding used Lua's `string.lower`, which only knows
  ASCII, so a Cyrillic query never matched a Cyrillic note name unless every letter's case matched
  exactly. Folding now goes through `vim.fn.tolower`.

### Added

- Made the Home `/` filter incremental: the list narrows as you type, group headings are searchable
  alongside names and paths, space-separated words all have to match, and matching is smart case.
- Added a `<leader>of` search prefix, `:ObsidianParaFind`, and `:ObsidianParaGrep` for finding notes
  by name or by content across the whole vault or one PARA section, plus `f` and `g` inside Home for
  the section currently open.
- Routed search through the first available picker (Snacks, fzf-lua, Telescope), pinnable with
  `search.provider`, with a no-dependency fallback that uses `vim.ui.select()` for names and the
  quickfix list for contents.
- Added the active picker and ripgrep availability to `:ObsidianParaHealth`.

## 0.2.1 - 2026-07-22

### Fixed

- Treated a note without frontmatter as a note with no properties instead of failing on the plain
  text the Obsidian CLI prints for it, so a Home section that contains such a note no longer
  collapses into `Obsidian CLI returned invalid JSON`.

## 0.2.0 - 2026-07-22

### Added

- Added a dedicated read-only Home dashboard with progressive Inbox and PARA summaries, grouped full
  lists, metadata details, filtering, launcher-style note opening, and Inbox capture or review
  handoff through `:ObsidianParaHome`, `<leader>oh`, and the `home()` Lua API.
- Added a responsive theme-aware constellation background with ASCII fallback and a validated
  custom provider that fully replaces the built-in preset.
- Added isolated Home model, loader, background, UI, controller, configuration, and API coverage,
  plus a read-only disposable-vault integration gate.

### Documentation

- Clarified that `v0.1.3` is the current published MVP release and moved the remaining manual
  evidence work into a separate post-release hardening milestone.
- Expanded the roadmap with Home, Daily notes, and explicitly non-committed later candidates.
- Recorded project-owner acceptance of `v0.1.3` and closed post-release stabilization within the
  agreed MVP scope.
- Added the accepted Home design, completed vertical implementation plan, architecture contract,
  manual scenarios, Vim help, and synchronized roadmap decisions.
- Recorded project-owner acceptance of the Home workflow for the `v0.2.0` release.

## 0.1.3 - 2026-07-22

### Fixed

- Consume an unrendered `<% tp.file.cursor() %>` marker from a QuickAdd-created Inbox note and
  place the Neovim cursor at that exact template position.

## 0.1.2 - 2026-07-22

### Fixed

- Supply QuickAdd Template choices with both the named `title` and reserved `value` inputs so
  non-interactive Inbox creation works with QuickAdd 2.12.3.

### Documentation

- Added a branded SVG banner and aligned the README header, badges, tagline, and navigation with
  the neighboring `obsidian-tasks.nvim` project.

## 0.1.1 - 2026-07-22

### Fixed

- Normalize JSON's optional escaped slash in merge-preview YAML so paths render identically on
  Neovim 0.10, 0.11, and 0.12.

## 0.1.0 - 2026-07-22

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
- Transactional `p/a/r/x` review actions with category-folder and `#area` pickers, archive-reason
  input, mutation-free preflight, metadata snapshotting, move-last execution, reverse rollback,
  and a terminal recovery report when compensation is incomplete.
- Window-independent review session state with FIFO advancement, per-pass skips, counters,
  pause semantics, and a terminal emergency state.
- Shared status, body, and footer review layout with centered configurable float and isolated
  fullscreen-tab variants.
- FIFO Inbox review startup that loads the oldest vault note into a listed, editable Markdown
  buffer and keeps its queue position, path, and planned action keys visible.
- Active buffer-local `e`, `s`, and `q` review actions with guarded saves, current-pass skip
  advancement, perform-now handoff, safe modified-buffer exit choices, and pass statistics.
- Confirmed `d` review action that saves safely, keeps cancellation first, moves notes only through
  Obsidian trash, blocks duplicate actions while pending, advances after CLI success, and preserves
  the current note on failure.
- Exact-path conflict resolver with labeled read-only target and Inbox panes, `<Tab>` focus
  switching, and persistent `m/r/d/q` actions.
- Conflict rename that validates a filename, repeats preflight, and uses the new name only in the
  final transactional PARA move without renaming the Inbox source first.
- Editable Merge Preview with target-first metadata, tag union, PARA normalization, neutral body
  composition, duplicate-H1 removal, and local `<leader>om` / `<leader>oq` actions.
- Transactional merge commit that revalidates source snapshots, writes the target, trashes the
  Inbox source last, restores the target on failure, and halts review after an incomplete restore.
- A fail-closed integration harness that verifies the exact selected vault and exercises a
  uniquely marked, non-overwriting create/read/move/read/trash fixture lifecycle with cleanup.
- The integration harness passes against the disposable `nvim-obsidian-para-flow-dev` vault with
  no marked fixture left in Inbox or Archives after completion.
- A stable-release evidence checklist covering both layouts, stock and Snacks `vim.ui`, WhichKey
  descriptions, external conflicts, move rollback, merge rollback, CI, and full Inbox flows.
- A concrete disposable-vault manual test procedure with stock/Snacks launch commands, exact
  expected results, cleanup, and a test-only CLI proxy for deterministic move and merge failures.
- Expanded Vim help with installation, review actions, integration verification, and
  troubleshooting guidance.

### Changed

- Review now defaults to a centered `70% × 70%` titled float with horizontal inset, a theme-derived
  chrome surface, concise queue context, and a bracketed command bar modeled on native pickers.
- Float review windows now follow the active theme's `Pmenu` popup surface with safe fallbacks.
  Configurable `review.winblend` defaults to `0`, preventing lower-buffer text from bleeding through.
- `<leader>on` now collects the Inbox title in Neovim and runs QuickAdd non-interactively, keeping
  the complete capture flow in the terminal.
- WhichKey now labels the default `<leader>o` mapping group as `obsidian para flow` when the
  optional WhichKey plugin is available and displays it with a purple crystal icon.
- Saving review actions now detect external file changes and Neovim write failures before changing
  session state, leaving the current note open when either guard fails.
- Review action mappings are removed from real note buffers during advance and exit so ordinary
  Markdown editing never retains review-only `d`, `e`, `s`, or `q` behavior.

### Documentation

- Added a release-ready GitHub project page with a guided Lazy.nvim installation, workflow,
  action reference, safety model, and contributor links.
- Documented `version = "*"` as the supported Lazy.nvim release channel so new semantic-version
  tags are discovered by `:Lazy update` and recorded in `lazy-lock.json`.
