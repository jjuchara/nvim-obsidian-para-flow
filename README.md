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
  A keyboard-first Inbox review workflow for Obsidian users who organize their notes with PARA.<br>
  Capture through QuickAdd, decide in Neovim, and keep your vault moving.
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
> `v0.1.x` is the MVP release line. Its core flow is covered by isolated and disposable-vault tests,
> while the full manual evidence gate for the first stable release remains in progress.

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

- Terminal-first capture through QuickAdd, with no Obsidian prompt stealing focus.
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
})
```

Default mappings are `<leader>on` for capture and `<leader>oi` for review. Set either
`mappings.new` or `mappings.review` to `false` to disable it, or provide another key sequence.
When WhichKey is installed, `<leader>o` is labeled `obsidian para flow` automatically.

Run `:ObsidianParaHealth` after setup. It checks Neovim, the CLI, exact vault identity,
QuickAdd choice, and configured folders without mutating the vault.

## Workflow

### 1. Capture

Press `<leader>on`, enter a title, and keep writing. The plugin validates the title, invokes the
configured QuickAdd choice non-interactively, discovers exactly one new Inbox file, opens it, and
places the cursor at an unrendered Templater `<% tp.file.cursor() %>` marker when present. The
marker is removed from the buffer; templates without it fall back below frontmatter and the first
heading.

If Obsidian is not running, the plugin opens the configured vault, waits up to 15 seconds for the
CLI, verifies that the correct vault became active, and retries once.

### 2. Review

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

### 3. Resolve conflicts

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
| `:ObsidianParaInboxNew` | Capture a new Inbox note. |
| `:ObsidianParaInboxReview` | Start or resume FIFO review. |
| `:ObsidianParaHealth` | Run read-only environment and vault checks. |

Public Lua API: `setup(options)`, `inbox_new()`, `inbox_review()`, and `health()`.

## Documentation

- [`:help obsidian-para-flow`](doc/obsidian-para-flow.txt) — complete user manual.
- [Architecture](ARCHITECTURE.md) — modules, state, transactions, and boundaries.
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
