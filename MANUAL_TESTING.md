# Manual Release Test

Run this procedure only against the disposable vault
`/Users/jjuchara/.local/state/nvim-obsidian-para-flow-dev`. Every note created below uses the
`__opf-manual-` prefix. Do not adapt the commands to a production vault.

## 1. Prepare and record the environment

1. Open the development vault in Obsidian and keep Obsidian running.
2. Confirm that QuickAdd is enabled and that its `inbox` choice uses `{{VALUE:title}}` in both the
   filename and template.
3. Confirm `2. Areas/My Areas.md` has the `area` tag. Projects and Resources require an existing
   tagged area note whenever the Inbox note has no `area` property.
4. In the repository, run:

   ```sh
   cd /Users/jjuchara/projects/nvim-plugin/nvim-obsidian-para-flow
   make check
   make test-integration TEST_VAULT=nvim-obsidian-para-flow-dev
   nvim --version | head -1
   obsidian vault=nvim-obsidian-para-flow-dev version
   ```

5. Record Neovim, Obsidian, QuickAdd, macOS, layout, and UI-provider versions in
   `RELEASE_CHECKLIST.md`.
6. Take a recoverable vault backup. `./scripts/nvim-dev --reset` moves the current development
   vault to a timestamped backup, but requires QuickAdd to be installed or copied again afterward.

Expected: both automated commands pass, the exact test vault name is reported, and no
`__obsidian-para-flow-integration-*` file remains in Inbox or Archives.

## 2. Launch the two UI variants

Use stock `vim.ui`:

```sh
OBSIDIAN_PARA_TEST_VAULT=nvim-obsidian-para-flow-dev \
  nvim --clean -u /Users/jjuchara/projects/nvim-plugin/nvim-obsidian-para-flow/tests/manual_init.lua
```

This opens plain Neovim without LazyVim, Snacks, or WhichKey and explicitly sets `<leader>` to
Space. It can be launched from any directory. Press the complete `Space o n` sequence without
pausing for Inbox capture, or `Space o i` for review. `Space o` alone has no popup because WhichKey
is intentionally absent; after the mapping timeout, native Vim interprets `o` as opening a line.

Use the LazyVim profile with its Snacks provider and WhichKey integration:

```sh
./scripts/nvim-dev
```

Use fullscreen review with either launcher:

```sh
OBSIDIAN_PARA_TEST_LAYOUT=fullscreen ./scripts/nvim-dev
```

Expected: stock prompts are usable; Snacks replaces them without changing results; WhichKey shows
`obsidian para flow`, `new Inbox note`, and `review Inbox`; the plugin still starts when Snacks and
WhichKey are absent.

## 3. Health and terminal capture

1. Run `:ObsidianParaHealth`; every required item must pass.
2. Press `<leader>on`, enter `__opf-manual-capture`, and submit.
3. Watch Obsidian while submitting: no QuickAdd dialog may appear there.
4. In Neovim, verify that `6. Inbox/__opf-manual-capture.md` opens in the current window and the
   cursor is at the removed `<% tp.file.cursor() %>` marker when the Inbox template contains one.
   Without that marker, verify the fallback below frontmatter and the first H1.
5. Repeat with an empty title, `../unsafe`, and `__opf-manual-capture` again.

Expected: only the first valid request creates a note. Cancellation, unsafe input, and a duplicate
stop before QuickAdd and do not open another file.

## 4. FIFO and `s/e/q/d`

Create three marked notes through `<leader>on`: `__opf-manual-01-oldest`,
`__opf-manual-02-middle`, and `__opf-manual-03-newest`. Set their `created` properties to
`01.07.2026 10:00`, `02.07.2026 10:00`, and `03.07.2026 10:00` respectively.

1. Start `<leader>oi`; `01-oldest` must open first and the footer must show `p/a/r/x/d/e/s/q`.
2. Edit the body, press `q`, select `Cancel`; the same modified note must remain open.
3. Press `q` again, select `Discard and exit`; the file on disk must retain its original body.
4. Restart review, press `s`; the saved oldest note is skipped only for this pass and `02-middle`
   opens.
5. Press `e`; review closes, the middle note opens in the originating window, and its path remains
   in Inbox.
6. Restart review, press `d`, select `Cancel`; the current note and counter must not change.
7. Press `d` again and confirm; the note moves through Obsidian trash and the next FIFO note opens.

Expected: no action advances more than once, skipped notes remain in Inbox, and the final summary
distinguishes processed, skipped, and remaining notes.

## 5. PARA actions and both layouts

Create four notes named `__opf-manual-project`, `__opf-manual-area`, `__opf-manual-resource`, and
`__opf-manual-archive`. Ensure `2. Areas/__opf-manual-area-source.md` exists with the `area` tag,
and create one nested folder under every PARA root in the test vault.

For each note, start review and select the matching action:

1. `p`: choose the Projects nested folder, then the marked area note.
2. `a`: choose the Areas root.
3. `r`: choose the Resources nested folder, then the marked area note.
4. `x`: choose the Archives nested folder and enter `manual release verification`.

Run two actions in float and two with `OBSIDIAN_PARA_TEST_LAYOUT=fullscreen`.

Expected: the chosen note moves last; existing body and properties survive; required tags, links,
`area`, or `archive_reason` are added only when missing. Closing float restores the original window;
closing fullscreen removes only its dedicated tab and restores the original tab layout.

## 6. External-change guard

1. Create `__opf-manual-external`, start review, and edit its body without saving.
2. From another terminal, change the same file through Obsidian or another editor and save it.
3. Return to Neovim and press `s`.

Expected: review reports an external change, does not write the Neovim buffer, does not advance the
queue, and leaves both versions available for manual reconciliation.

## 7. Conflict resolver and successful merge

For each resolver action, create an Inbox note and an exact same-name target in `1. Projects`.
Choose `p` and the Projects root to enter conflict mode.

1. Confirm both labeled panes are read-only and `<Tab>` moves focus between them.
2. Press `q`; the original editable Inbox buffer must return unchanged.
3. Re-enter conflict mode, press `r`, and enter a unique final name. The source must move directly
   to that final target without an intermediate Inbox rename.
4. With a fresh conflict, press `d`: first cancel, then repeat and confirm. Only the Inbox source
   may go to trash.
5. With a fresh conflict, press `m`. Edit Merge Preview, press `<leader>oq`, and confirm neither
   source changed. Reopen preview, edit it, and press `<leader>om`.

Expected after merge: target metadata wins, tags are unioned, bodies are separated by `---`, only
an exactly duplicated first Inbox H1 is removed, the target contains the approved preview, and the
Inbox source is in trash.

## 8. Deterministic move rollback

The repository includes a test-only CLI proxy. It forwards every command except the fault selected
by `OBSIDIAN_PARA_FAULT`.

```sh
real_cli=$(command -v obsidian)
PATH="$PWD/tests/manual/bin:$PATH" \
OBSIDIAN_PARA_REAL_CLI="$real_cli" \
OBSIDIAN_PARA_FAULT=move \
./scripts/nvim-dev
```

1. Create `__opf-manual-move-rollback` without PARA metadata.
2. Start review, press `x`, choose Archives, and enter `manual rollback`.

Expected: property changes occur first, the injected move fails, all added properties are removed
in reverse order, the source remains in Inbox, the queue does not advance, and review remains usable.
Exit this Neovim instance before testing without the proxy.

## 9. Deterministic merge rollback

Create exactly these two files with different bodies:

- `6. Inbox/__opf-manual-merge-rollback.md`
- `1. Projects/__opf-manual-merge-rollback.md`

Launch with the delete fault targeted only at that Inbox source:

```sh
real_cli=$(command -v obsidian)
PATH="$PWD/tests/manual/bin:$PATH" \
OBSIDIAN_PARA_REAL_CLI="$real_cli" \
OBSIDIAN_PARA_FAULT=merge-trash \
./scripts/nvim-dev
```

Start review, choose `p` and the Projects root, open Merge Preview, make a recognizable edit, and
apply it with `<leader>om`.

Expected: target write succeeds, the injected source-trash step fails, the original target content
is restored, the Inbox source remains, the queue does not advance, and review reports the failed
merge without claiming success.

## 10. Cleanup and evidence

1. Search the test vault for `__opf-manual-`.
2. Send every manual fixture to Obsidian trash; do not permanently delete it as part of testing.
3. Confirm no marked fixture remains in Inbox, Projects, Areas, Resources, or Archives.
4. Check the corresponding boxes in `RELEASE_CHECKLIST.md` and add the observed versions and date.
5. Run `make check` once more.

Do not check a scenario merely because an isolated automated test covers it. Record the actual
manual result, including any deviation.
