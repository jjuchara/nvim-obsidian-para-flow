# Roadmap

## Released MVP (`v0.1.x`)

- [x] Repository skeleton, development tools, isolated tests, and CI.
- [x] Validated public configuration, API, commands, and mappings.
- [x] Asynchronous Obsidian CLI adapter and read-only health diagnostics.
- [x] QuickAdd Inbox creation, safe path discovery, opening, and cursor placement.
- [x] Inbox domain model, FIFO ordering, and metadata rules.
- [x] Review UI and window-independent session state machine.
- [x] Transactional PARA sorting with rollback and recovery reporting.
- [x] Conflict resolver and editable merge preview.
- [x] Integration harness, provider contract coverage, Vim help, release CI, and public release
  documentation.
- [x] Publish the MVP release line through `v0.1.3`.

## Post-release hardening

- [x] Complete and record the agreed disposable-vault scenarios in `RELEASE_CHECKLIST.md`.
- [x] Review real use of the `v0.1.x` release line and confirm that no blocking workflow or
  compatibility regressions remain within the agreed MVP scope.
- [x] Accept `v0.1.3` as stable within the agreed MVP scope.

## Home workflow

- [x] Define the smallest useful Home dashboard contract and its read-only data sources.
- [x] Design keyboard-first navigation from Home to Inbox and PARA destinations.
- [x] Implement Home incrementally with isolated coverage and disposable-vault verification.
- [x] Release confirmed Obsidian-trash actions for Home and every search backend in `v0.5.0`.
- [x] Add manual multi-note merge from the current filtered Home and search result sets.
- [x] Add ordered selection, explicit target choice, editable preview, visible action hints, and
  multi-source recovery coverage.
- [x] Publish the automated multi-note merge scope in `v0.6.0`; retain the expanded disposable-vault
  backend scenario as an explicit follow-up evidence gate.

## Template capture and todo integration

- [x] Add named QuickAdd capture profiles with explicit destination folders.
- [x] Add profile selection through `<leader>ot`, `:ObsidianParaCapture`, and Lua API.
- [x] Keep note-and-todo capture available through command, Lua API, and an opt-in mapping.

## Obsidian desktop Inbox review — next

- [ ] Build a separate Obsidian plugin with the same predictable Inbox review workflow.
- [ ] Define one shared queue, PARA-action, preflight, apply, and recovery contract for both clients.
- [ ] Verify desktop review in a disposable vault before connecting it to a production vault.

## Daily notes workflow

- [ ] Define creation, opening, template, and date-navigation behavior through Obsidian CLI.
- [ ] Decide how Daily notes connect to Inbox capture and PARA processing without coupling the
  workflows.
- [ ] Implement Daily notes after the desktop Inbox review workflow is established.

## Later candidates

These are discovery topics, not committed release scope.

- [ ] Evaluate multiple named vault profiles.
- [ ] Evaluate configurable categories beyond the fixed PARA model.
- [ ] Reassess headless workflows only if Obsidian CLI can preserve the current safety contract.
