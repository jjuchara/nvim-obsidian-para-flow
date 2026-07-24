<p align="center">
  <img src="assets/banner.svg" alt="obsidian-para-flow.nvim" width="100%">
</p>

<p align="center">
  <a href="https://github.com/jjuchara/nvim-obsidian-para-flow/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/jjuchara/nvim-obsidian-para-flow/ci.yml?branch=main&amp;style=for-the-badge&amp;logo=github&amp;label=tests" alt="Tests"></a>
  <a href="https://github.com/jjuchara/nvim-obsidian-para-flow/releases/latest"><img src="https://img.shields.io/github/v/release/jjuchara/nvim-obsidian-para-flow?display_name=tag&amp;sort=semver&amp;style=for-the-badge&amp;color=8b5cf6" alt="Latest release"></a>
  <img src="https://img.shields.io/badge/Neovim-0.10%2B-57A143?style=for-the-badge&amp;logo=neovim&amp;logoColor=white" alt="Neovim 0.10+">
  <img src="https://img.shields.io/badge/dependencies-zero-22c55e?style=for-the-badge" alt="Zero dependencies">
</p>

<p align="center">
  A keyboard-first Home and Inbox workflow for Obsidian users who organize notes with PARA.<br>
  Navigate the vault, capture through QuickAdd, decide in Neovim, and keep knowledge moving.
</p>

<p align="center">
  <a href="#installation">Install</a> ·
  <a href="#configuration">Configure</a> ·
  <a href="#workflow">Use</a> ·
  <a href="ROADMAP.md">Roadmap</a> ·
  <a href="doc/obsidian-para-flow.txt">:help obsidian-para-flow</a>
</p>

---

> [!IMPORTANT]
> `v0.6.1` is the current stable release. The original `v0.1.x` MVP scope and the later Home,
> search, capture, trash, and multi-note merge workflows are covered by isolated tests; the core
> Inbox flow also has a disposable-vault integration gate.

## Why this plugin?

An Inbox only works when processing it is easier than ignoring it. `obsidian para flow.nvim`
turns review into a focused queue: one real Markdown buffer, one decision, then the next note.
Obsidian remains the source of truth and every vault mutation goes through its official CLI.

```text
Quick capture          Focused review               Safe destination

<leader>on   ───────▶  oldest Inbox note  ───────▶  Projects   [p]
                       edit in place                 Areas      [a]
                       save / skip / delete           Resources  [r]
                       resolve name conflicts         Archives   [x]
```

### MVP highlights

- Navigation-first Home dashboard with progressive PARA lists, metadata details, incremental
  filtering, direct note opening, and confirmed deletion through Obsidian trash.
- Vault-wide and per-section search that reuses your installed picker, with a working fallback when
  none is installed.
- Manual semantic-deduplication from filtered Home and search results, with ordered multi-selection,
  an explicit retained note, and editable merge preview.
- Terminal-first capture through QuickAdd, with no Obsidian prompt stealing focus.
- Named QuickAdd capture profiles for creating templated notes directly in configured vault folders.
- Optional handoff to `obsidian-tasks.nvim` after an explicit note-and-todo capture.
- FIFO review in a polished centered float or an isolated fullscreen tab.
- Always-visible `p/a/r/x/d/e/s/q` actions and provider-friendly `vim.ui` prompts.
- Transactional PARA moves: validate first, update metadata, move last, roll back on failure.
- Side-by-side name conflict resolution with rename, delete, and editable merge preview.
- External-change detection, safe modified-buffer exit, and explicit recovery reports.
- No mandatory Neovim plugin dependencies; Snacks and WhichKey are optional enhancements.

## Requirements

- Neovim 0.10 or newer. CI covers 0.10, 0.11, and 0.12.
- Obsidian installed with the 1.12.7 or newer installer.
- [Obsidian CLI](https://help.obsidian.md/cli) enabled and the desktop app running.
- QuickAdd 2.12 or newer with an Inbox choice whose filename and template use
  `{{VALUE:title}}`. The plugin supplies both QuickAdd's named `title` and reserved `value` inputs
  for compatibility with Template choices in QuickAdd 2.12.3.

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "jjuchara/nvim-obsidian-para-flow",
  version = "*", -- Follow the newest semantic-version release.
  opts = {
    -- Add the mandatory vault configuration shown below.
  },
}
```

`version = "*"` keeps the installation on tagged releases. After a new version is published,
`:Lazy update` upgrades the plugin and refreshes `lazy-lock.json`. Remove `version` only if you
prefer to follow every commit on `main`.

## Configuration

All paths are explicit and vault-specific. The plugin never guesses a personal vault layout.

```lua
require("obsidian-para-flow").setup({
  vault = "My Vault", -- Exact name known to Obsidian CLI.
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
  review = {
    layout = "float", -- or "fullscreen"
    width = 0.7,
    height = 0.7,
    winblend = 0,
  },
  home = {
    preview_limit = 5,
    projects = {
      status_order = { "В работе", "Планируется" },
    },
    background = {
      provider = "constellation", -- false, preset name, or a function
      intensity = 0.12,
    },
  },
  search = {
    provider = "auto", -- snacks, fzf-lua, telescope, or builtin
  },
  capture = {
    profiles = {
      meeting = {
        label = "Meeting note",
        folder = "3. Resources/Meetings",
        quickadd_choice = "meeting",
        prompt = "Meeting title: ", -- Optional; derived from label when omitted.
        todo = false, -- true starts obsidian-tasks.nvim after the note opens.
      },
    },
  },
})
```

Default mappings are `<leader>oh` for Home, `<leader>on` for Inbox capture, `<leader>ot` for a named
template profile, `<leader>oi` for review, and `<leader>of` as the search prefix. Note-and-todo
capture remains available through `:ObsidianParaInboxNewWithTask` and `inbox_new_with_task()` but
has no default mapping; assign `mappings.new_with_task` to opt in. Set any other `mappings` field to
`false` to disable it, or provide another key sequence.
When WhichKey is installed, `<leader>o` is labeled `obsidian para flow` automatically.

Run `:ObsidianParaHealth` after setup. It checks Neovim, the CLI, exact vault identity, every Inbox
or capture-profile QuickAdd choice, and configured folders without mutating the vault.

## Workflow

### 1. Navigate from Home

Press `<leader>oh` to open a dedicated dashboard. Home progressively loads the configured Inbox,
Projects, Areas, Resources, and Archives through Obsidian CLI. Projects is the primary wide layout
section; medium layouts use two columns and narrow layouts show one active section.

Use `j/k` and `<Tab>` to move, `p/a/r/x` to open grouped full lists, `/` to filter, and `<Enter>` to
open a selected Markdown note in a new tab without replacing the originating repository. `f` and
`g` hand the current scope to the
picker (see below). `d` asks for confirmation and moves the selected note to Obsidian trash from
either the overview or a full section; after success, Home removes it from the current layout
without closing. `m` starts merge selection from the currently visible notes. `n` hands off to
Inbox capture, `i` starts review, `R` refreshes, and `q` closes
Home. Wide full lists include read-only metadata details but never load the note body while
navigating.

`/` narrows the list as you type, across names, paths, and group headings such as a project status
or an area. Matching is smart case and folds non-ASCII text, so `ресурс` finds `Ресурсы 2024` while
`Ресурс` stays exact. Space-separated words must all match. `<BS>` deletes a character, `<C-w>` a
word, `<C-u>` the whole query, `<Enter>` keeps it, and `<Esc>` restores the previous one.

The default constellation background follows the active theme and falls back to ASCII. Set its
provider to `false` or replace it with a callback returning `{ row, col, text }` fragments; a custom
provider fully replaces the preset and cannot break dashboard navigation.

### 2. Capture

Press `<leader>on`, enter a title, and keep writing. The plugin validates the title, invokes the
configured QuickAdd choice non-interactively, discovers exactly one new Inbox file, opens it, and
places the cursor at an unrendered Templater `<% tp.file.cursor() %>` marker when present. The
marker is removed from the buffer; templates without it fall back below frontmatter and the first
heading.

Press `<leader>ot` to choose a configured capture profile and create a templated note directly in
that profile's folder. The profile reuses the same fail-closed before/after discovery as Inbox
capture and must name a QuickAdd choice that creates exactly one Markdown file below that folder.
Profile keys use letters, digits, `_`, or `-`; `label` is the unrestricted display name.

Run `:ObsidianParaInboxNewWithTask` when the Inbox note also needs an actionable todo. The note is
created and opened first, then the public `require("obsidian-tasks").create()` flow starts. This
integration is optional: ordinary capture has no task prompt and `obsidian-tasks.nvim` is not a
runtime dependency. Assign `mappings.new_with_task` to opt into a shortcut, or let a capture profile
use the same handoff with `todo = true`.

If Obsidian is not running, the plugin opens the configured vault, waits up to 15 seconds for the
CLI, verifies that the correct vault became active, and retries once.

### 3. Review

Press `<leader>oi`. The oldest Inbox note opens as a real editable Markdown buffer. The review
session keeps queue position, path, and actions visible:

| Key | Action | Result |
| --- | --- | --- |
| `p` | Project | Choose a Projects folder and, when needed, an `#area` note. |
| `a` | Area | Choose an Areas folder. |
| `r` | Resource | Choose a Resources folder and, when needed, an `#area` note. |
| `x` | Archive | Choose an Archives folder and provide an archive reason. |
| `d` | Delete | Confirm, then move the Inbox note to Obsidian trash. |
| `e` | Edit now | Save, pause review, and return the note to the original window. |
| `s` | Skip | Save and skip the note for this review pass. |
| `q` | Quit | Exit safely, prompting when the buffer has unsaved changes. |

### 4. Search the vault

`<leader>of` opens a search prefix that works anywhere, not just inside Home:

| Key | Scope |
| --- | --- |
| `<leader>off` | Find notes across the whole vault. |
| `<leader>ofi` | Find notes in Inbox. |
| `<leader>ofp` / `ofa` / `ofr` / `ofx` | Find notes in Projects / Areas / Resources / Archives. |
| `<leader>ofg` | Search note contents across the vault. |
| `<leader>ofG` | Search note contents in one PARA section. |

`:ObsidianParaFind [category]` and `:ObsidianParaGrep [category]` do the same from the command line.

Searching runs on whichever picker is installed — Snacks, fzf-lua, or Telescope, in that order —
scoped to the vault folder and limited to Markdown. Pin one with `search.provider`. With no picker
installed the plugin still works: file search falls back to `vim.ui.select` and content search
fills the quickfix list from ripgrep. Content search needs `rg`; `:ObsidianParaHealth` reports both
the active picker and whether ripgrep is available. When search starts outside the vault, its
default selection opens in a new tab; searches started inside the vault keep the current tab.
Searches launched from Home always preserve the originating tab.

Press `<C-d>` on a selected result in Snacks, fzf-lua, or Telescope to confirm moving its note to
Obsidian trash; the picker reopens after the operation. The built-in file fallback offers Open or
Move to trash after selection, while the built-in content-search quickfix list uses `d` and removes
all matches from the trashed note after success.

Press `<C-o>` to merge notes from the current filtered search result (`m` in Home). Search surfaces
keep `[Enter] Open  [Ctrl+O] Merge  [Ctrl+D] Trash`
visible using the native footer, header, or result-title surface supported by the active backend.
The common merge window uses `Space` to record at least two notes in order, `Enter` to continue,
and `Esc` to cancel. A second short step explicitly chooses the note whose path will be kept.

The editable result keeps that target's frontmatter as the base, fills only missing properties from
the other notes, and unions tags. Every selected body — including the target — appears under
`## <filename without .md>`, with `---` between blocks. Source frontmatter is not copied into the
body, while original headings and Markdown remain editable. `<leader>om` revalidates every source,
writes the target, and then moves the other notes to Obsidian trash; `<leader>oq` cancels. A modified
Neovim buffer or changed on-disk source stops commit before mutation.

### 5. Resolve conflicts

If the destination already contains the same filename, review switches to labeled target and
Inbox panes. Use `<Tab>` to change focus, then merge, rename, delete the Inbox source, or return.
Merge opens an editable preview and commits only after both source snapshots are revalidated.

## Safety model

The plugin fails closed around vault writes:

1. Complete every prompt and validate source, destination, and current vault.
2. Save the edited buffer only if its on-disk fingerprint is unchanged.
3. Snapshot metadata, apply only missing properties, and move the note last.
4. Compensate completed steps in reverse order when a later step fails.
5. Halt review with exact recovery details if compensation cannot finish safely.

No permanent-delete path exists. Delete actions use Obsidian trash.

## Commands

| Command | Purpose |
| --- | --- |
| `:ObsidianParaHome` | Open or focus the Home dashboard. |
| `:ObsidianParaFind [category]` | Find Markdown notes by name in the vault or one section. |
| `:ObsidianParaGrep [category]` | Search Markdown contents in the vault or one section. |
| `:ObsidianParaInboxNew` | Capture a new Inbox note. |
| `:ObsidianParaInboxNewWithTask` | Capture an Inbox note, then start optional todo creation. |
| `:ObsidianParaCapture [profile]` | Create through a named template profile, or choose one. |
| `:ObsidianParaInboxReview` | Start or resume FIFO review. |
| `:ObsidianParaHealth` | Run read-only environment and vault checks. |

Public Lua API: `setup(options)`, `home()`, `inbox_new()`, `inbox_new_with_task()`, `capture(profile)`,
`inbox_review()`, `find(category)`, `grep(category)`, and `health()`.

## Documentation

- [`:help obsidian-para-flow`](doc/obsidian-para-flow.txt) — complete user manual.
- [Architecture](ARCHITECTURE.md) — modules, state, transactions, and boundaries.
- [Home design](HOME_DESIGN.md) and [implementation plan](HOME_IMPLEMENTATION_PLAN.md) — accepted
  dashboard behavior, visual system, and delivered vertical slices.
- [Contributing](CONTRIBUTING.md) — development setup and verification.
- [Roadmap](ROADMAP.md) and [changelog](CHANGELOG.md) — release progress and user-visible changes.
- [Release checklist](RELEASE_CHECKLIST.md) and [manual testing](MANUAL_TESTING.md) — stable-release evidence.

## Development

The plugin is Lua-only and has no build step.

```sh
make check
```

This runs StyLua, Selene, isolated `mini.test` coverage, shell checks, and Vim help generation.
The opt-in disposable-vault gate is intentionally separate:

```sh
make test-integration TEST_VAULT=nvim-obsidian-para-flow-dev
```

Never point the integration or manual workflows at a production vault. See
[CONTRIBUTING.md](CONTRIBUTING.md) for the isolated `./scripts/nvim-dev` profile.
