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

## Daily notes workflow

- [ ] Define creation, opening, template, and date-navigation behavior through Obsidian CLI.
- [ ] Decide how Daily notes connect to Inbox capture and PARA processing without coupling the
  workflows.
- [ ] Implement Daily notes after the Home workflow is stable.

## Later candidates

These are discovery topics, not committed release scope.

- [ ] Evaluate multiple named vault profiles.
- [ ] Evaluate configurable categories beyond the fixed PARA model.
- [ ] Reassess headless workflows only if Obsidian CLI can preserve the current safety contract.
