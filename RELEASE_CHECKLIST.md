# Release Checklist

This checklist is the evidence record for the first stable release. A checked manual item means
that it was observed in a disposable test vault, not inferred from an isolated test.

The `v0.1.0` MVP may be published as an explicitly labeled MVP release before this stable gate is
complete. It uses a normal semantic-version tag so Lazy.nvim users on `version = "*"` receive
future tagged updates; publishing it does not mark the unchecked stable evidence as complete.

## Automated gate

- [x] `make check` passes locally on 2026-07-22 with 99 isolated cases.
- [x] The GitHub Actions lint job and Neovim `0.10.4`, `0.11.4`, and `0.12.2` matrix pass for the
  `v0.1.1` compatibility commit on 2026-07-22.
- [x] `make test-integration TEST_VAULT=nvim-obsidian-para-flow-dev` passes against the disposable
  release vault on 2026-07-22: 2 cases, 0 failures, with no fixture left in Inbox or Archives.

Integration environment: Neovim `0.12.2`, Obsidian `1.12.7` (installer `1.12.7`), QuickAdd
`2.12.3`, vault path `/Users/jjuchara/.local/state/nvim-obsidian-para-flow-dev`.

The integration gate verifies the exact open vault name, creates a unique note whose filename and
frontmatter identify it as an `obsidian-para-flow` fixture, reads it, moves it from the configured
Inbox to Archives, reads it again, and sends it to the vault trash. It never overwrites an existing
path and attempts cleanup after a failed assertion. Use these optional overrides only when the test
vault does not use the documented example folders:

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

- [ ] Capture: `<leader>on` prompts in Neovim, QuickAdd creates exactly one marked Inbox note, the
  note opens below frontmatter and H1, and Obsidian shows no QuickAdd prompt.
- [ ] FIFO review: prepare at least three marked notes with distinct `created` values; confirm
  oldest-first order and exercise `s`, `e`, `q` with cancel/save/discard, and `d` with cancel and
  confirm.
- [ ] PARA sorting: exercise `p`, `a`, `r`, and `x`, including nested folder selection, `#area`
  selection, archive reason, successful metadata changes, and final move.
- [ ] Layouts: complete review actions once in the default float and once in fullscreen; confirm
  the originating window and tab layout are restored.
- [ ] External conflict: edit the current note outside Neovim before an action; confirm the action
  stops, the queue does not advance, and neither version is overwritten.
- [ ] Move rollback: induce a move failure after property changes; confirm all applied properties
  are restored and the current Inbox note remains open.
- [ ] Conflict resolver: exercise comparison focus, cancel, rename, delete cancel/confirm, Merge
  Preview edit/cancel, and a successful merge.
- [ ] Merge rollback: induce source-trash failure after target write; confirm the target is restored,
  the Inbox source remains, and the queue does not advance.
- [ ] Providers: repeat prompts with stock `vim.ui` and a Snacks `vim.ui` provider; confirm mappings
  expose their descriptions and the optional WhichKey group renders without becoming required.

## Release decision

- [ ] Both capture and complete review end-to-end scenarios finish without data loss or an unsafe
  partial operation.
- [ ] README, Vim help, changelog, decision log, roadmap, and Russian second-brain mirrors describe
  the observed release behavior.
- [ ] The release commit is clean, the CI gate is green, and the stable version/tag is recorded in
  the changelog.

Do not tag the first stable release while any item in this section is unchecked.
