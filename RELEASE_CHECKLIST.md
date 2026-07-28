# Release Checklist

This checklist is the cumulative release-evidence record for the published plugin. A checked
manual item means that it was observed in a disposable test vault, not inferred from an isolated
test.

The project owner accepted the agreed `v0.1.x` behavior on 2026-07-22. The completed items below
record that scope acceptance without expanding the MVP contract.

The published release line currently reaches `v0.9.5` and uses normal semantic-version tags so
Lazy.nvim users on `version = "*"` receive future tagged updates. Publishing a tag does not mark
unchecked manual evidence as complete.

## Automated gate

- [x] Current expired-note review development `make check` passes locally on 2026-07-28 with 186
  isolated cases, including exact-vault refusal, both strict date formats, category property selection,
  Archives exclusion, invalid metadata, a direct provider-independent queue action surface, project
  status replacement, and rollback coverage.
- [x] GitHub Actions tag/main runs `30388778162` and `30388778735` pass for commit
  `93bf6d6d6ef30cc169a7d17516ac531ee4eb6565` on Neovim 0.10–0.12; annotated tag and GitHub Release
  `v0.9.4` are published. ✅ 2026-07-28
- [x] GitHub Actions run `30386344818` passes for commit
  `e9b5bc06224dca99b23b3fd89a8f87e7f5c662a3` on Neovim 0.10–0.12; annotated tag and GitHub Release
  `v0.9.3` are published. The broader manual expired-note evidence remains open. ✅ 2026-07-28
- [x] GitHub Actions run `30378687024` passes for commit
  `aa315d2ee5ef0689d83a0e9e2a9052f65859f66b` on Neovim 0.10–0.12; annotated tag and GitHub Release
  `v0.9.2` are published. The owner-authorized manual evidence remains open. ✅ 2026-07-28

- [x] Current Daily notes development `make check` passes locally on 2026-07-27 with 177 isolated
  cases, including public API documentation coverage, exact CLI argv, aliases, canceled prompts,
  read-only output, new-tab preservation, exact-vault preflight, and the required-core-plugin health
  check.
- [x] The development launcher fixture enables Daily notes and supplies deterministic folder,
  format, and core-template settings; its reset/prepare shell gate passes.

- [x] Current development `make check` passes locally on 2026-07-24 with 168 isolated cases,
  including compact neutral merge selection, Home/search rename across every backend, modified
  buffer and destination-conflict guards, loaded-buffer path updates, ordered merge selection,
  multi-source commit, and partial recovery reporting.
- [x] GitHub Actions run `30084441914` passes for the `v0.7.0` commit `9aa5f92` on 2026-07-24:
  lint and the Neovim `0.10.4`, `0.11.4`, and `0.12.2` matrix are green. The annotated tag and
  GitHub Release are published.
- [x] GitHub Actions run `30082411901` passes for the `v0.6.2` commit `b1b0daa` on 2026-07-24:
  lint and the Neovim `0.10.4`, `0.11.4`, and `0.12.2` matrix are green. The patch makes the new
  built-in quickfix test independent of globally installed ripgrep on Linux runners.
- [x] `make check` passes locally on 2026-07-23 with 146 isolated cases, including Home, vault
  search, named template capture, optional todo handoff, health diagnostics, configuration, and API
  contracts.
- [x] GitHub Actions run `30015373936` passes for the `v0.5.0` commit `1bbe5fa` on 2026-07-23:
  lint and the Neovim `0.10.4`, `0.11.4`, and `0.12.2` matrix are green.
- [x] `make test-integration TEST_VAULT=nvim-obsidian-para-flow-dev` passes against the disposable
  release vault on 2026-07-23: 3 cases, 0 failures, including read-only loading of every Home
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

- [ ] Expired-note review: on a disposable vault verify `deadline`/`expired_at`, today/future/invalid
  exclusion, rescheduling, both default project statuses, archive folder/reason, conflict/rollback,
  trash cancel/success, skip/close, and exact-vault refusal. Do not use the production vault.

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
- [x] Multi-note merge: the project owner completed the Home and all-search-backend manual flow on
  2026-07-24 and confirmed it works. The check covered persistent action hints, selection order,
  cancellation of an edited preview, commit into an explicitly chosen target, and confirmation
  that non-target notes reach Obsidian trash only after the target write.
- [x] Daily notes open: on 2026-07-27 the project owner confirmed that `<leader>od`/
  `:ObsidianParaDaily` works after selecting `nvim-obsidian-para-flow-dev`; the exact-vault guard
  first refused the active production vault and performed no Daily action there.
- [ ] Daily notes extended evidence: on the disposable vault verify configured template content,
  path/read output, append/prepend prompts and every alias, plus fail-closed behavior when Daily
  notes is disabled. Do not use the production vault.

## Release decision

- [x] Both capture and complete review end-to-end scenarios finish without data loss or an unsafe
  partial operation.
- [x] README, Vim help, changelog, decision log, roadmap, and Russian second-brain mirrors describe
  the observed release behavior.
- [x] The release commit is clean, the CI gate is green, and the stable version/tag is recorded in
  the changelog.

The post-release stabilization gate is complete for the agreed `v0.1.x` scope.
The Home release gate is complete for the accepted `v0.2.0` scope.
The automated release gate is complete for the `v0.4.0` template-capture and todo-handoff scope.
The automated release gate is complete for the `v0.5.0` Home and search trash-action scope.
The automated and expanded manual backend gates are complete for the `v0.6.0` multi-note merge
scope.
The `v0.7.0` release adds safe Home/search rename and the merge-selector UI correction. Its local
and GitHub automated gates are complete, and the project owner confirmed the corrected selector in
the completed manual multi-backend merge flow on 2026-07-24.
The `v0.8.0` release adds the Daily notes command family and required-core-plugin diagnostics. Its
automated gate and confirmed open-path smoke test are complete; the expanded alias/template manual
evidence remains explicitly open.
Release commit `83de9b60463bb5fd6adae0ee2a9240a4895927fe`, annotated tag `v0.8.0`, and the
GitHub Release all resolve to the same code. GitHub Actions run `30278139084` completed successfully
for that commit on Neovim 0.10–0.12.

The `v0.9.0` release adds explicit expired-note review. On 2026-07-28 the owner explicitly
authorized publication before its disposable-vault manual gate and chose to validate it in normal
use. The 182-case local automated gate is green; the expired-note checkbox above remains open and
must not be interpreted as completed evidence.
Release commit `1bf37bffb41c07ce74ff9946b1ee02e7b83a0571`, annotated tag `v0.9.0`, and the
published GitHub Release resolve to the same code. GitHub Actions run `30375089834` completed
successfully for that commit on Neovim 0.10–0.12.

Patch `v0.9.1` fixes JSON-null/blank expiration properties discovered during normal-use
validation. Release commit `e9d66d51ca1509eb649464f38702550759fc2f4f`, annotated tag, and the
published GitHub Release resolve to the same code; CI run `30376690846` is green on Neovim
0.10–0.12. The broader manual expired-note gate remains open.
