# Release Checklist

This checklist is the post-release evidence record for the first post-MVP stable milestone. A
checked manual item means that it was observed in a disposable test vault, not inferred from an
isolated test.

The project owner accepted the agreed `v0.1.x` behavior on 2026-07-22. The completed items below
record that scope acceptance without expanding the MVP contract.

The published `v0.1.x` MVP line, currently at `v0.1.3`, uses normal semantic-version tags so
Lazy.nvim users on `version = "*"` receive future tagged updates. Publishing an MVP tag does not
mark unchecked manual evidence as complete.

## Automated gate

- [x] `make check` passes locally on 2026-07-22 with 112 isolated cases, including the Home model,
  loader, background, responsive UI, controller, configuration, and API contracts.
- [x] The GitHub Actions lint job and Neovim `0.10.4`, `0.11.4`, and `0.12.2` matrix pass for the
  `v0.1.1` compatibility commit on 2026-07-22.
- [x] `make test-integration TEST_VAULT=nvim-obsidian-para-flow-dev` passes against the disposable
  release vault on 2026-07-22: 3 cases, 0 failures, including read-only loading of every Home
  section, with no fixture left in Inbox or Archives.

Integration environment: Neovim `0.12.2`, Obsidian `1.12.7` (installer `1.12.7`), QuickAdd
`2.12.3`, vault path `/Users/jjuchara/.local/state/nvim-obsidian-para-flow-dev`.

The integration gate verifies the exact open vault name, creates a unique note whose filename and
frontmatter identify it as an `obsidian-para-flow` fixture, reads it, moves it from the configured
Inbox to Archives, reads it again, and sends it to the vault trash. A separate read-only case loads
Inbox and all four configured PARA roots through the Home loader. The gate never overwrites an
existing path and attempts cleanup after a failed assertion. Use these optional overrides only when
the test vault does not use the documented example folders:

```sh
OBSIDIAN_PARA_TEST_INBOX='6. Inbox' \
OBSIDIAN_PARA_TEST_ARCHIVES='4. Archives' \
make test-integration TEST_VAULT='nvim-obsidian-para-flow-dev'
```

Never point this command at a production vault. Confirm the vault name shown in Obsidian before
starting; the harness fails before mutation when the CLI resolves a different name.

## Manual end-to-end scenarios

Follow [MANUAL_TESTING.md](MANUAL_TESTING.md). It defines the exact fixtures, launch commands,
fault-injection modes, actions, and expected results used by the checkboxes below.

Record the date, Neovim version, Obsidian version, QuickAdd version, UI provider, layout, and a
short result beside every completed group.

- [x] Capture: `<leader>on` prompts in Neovim, QuickAdd creates exactly one marked Inbox note, the
  note opens at the consumed Templater cursor marker (or the fallback below frontmatter and H1),
  and Obsidian shows no QuickAdd prompt.
- [x] FIFO review: prepare at least three marked notes with distinct `created` values; confirm
  oldest-first order and exercise `s`, `e`, `q` with cancel/save/discard, and `d` with cancel and
  confirm.
- [x] PARA sorting: exercise `p`, `a`, `r`, and `x`, including nested folder selection, `#area`
  selection, archive reason, successful metadata changes, and final move.
- [x] Layouts: complete review actions once in the default float and once in fullscreen; confirm
  the originating window and tab layout are restored.
- [x] External conflict: edit the current note outside Neovim before an action; confirm the action
  stops, the queue does not advance, and neither version is overwritten.
- [x] Move rollback: induce a move failure after property changes; confirm all applied properties
  are restored and the current Inbox note remains open.
- [x] Conflict resolver: exercise comparison focus, cancel, rename, delete cancel/confirm, Merge
  Preview edit/cancel, and a successful merge.
- [x] Merge rollback: induce source-trash failure after target write; confirm the target is restored,
  the Inbox source remains, and the queue does not advance.
- [x] Providers: repeat prompts with stock `vim.ui` and a Snacks `vim.ui` provider; confirm mappings
  expose their descriptions and the optional WhichKey group renders without becoming required.
- [x] Home: the project owner verified the implemented Home workflow in real use on 2026-07-22 and
  accepted it for the `v0.2.0` release.

## Release decision

- [x] Both capture and complete review end-to-end scenarios finish without data loss or an unsafe
  partial operation.
- [x] README, Vim help, changelog, decision log, roadmap, and Russian second-brain mirrors describe
  the observed release behavior.
- [x] The release commit is clean, the CI gate is green, and the stable version/tag is recorded in
  the changelog.

The post-release stabilization gate is complete for the agreed `v0.1.x` scope.
The Home release gate is complete for the accepted `v0.2.0` scope.
