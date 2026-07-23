# Home Implementation Plan

## Scope

Implement the accepted Home dashboard, navigation, replaceable background, progressive CLI data
loading, isolated coverage, disposable-vault verification, and complete public and project
documentation. Daily notes, tasks, metadata editing, body preview, multiple vaults, and custom PARA
categories remain out of scope. The only direct mutation is confirmed movement to Obsidian trash.

## Completed vertical slices

- [x] Define the Home data, layout, keyboard, visual, error, and public configuration contracts.
- [x] Add `home()`, `:ObsidianParaHome`, `<leader>oh`, validated Home options, and WhichKey exposure.
- [x] Add a pure Home model for semantic filtering, sorting, grouping, and search.
- [x] Add a bounded progressive loader with safe paths, independent sections, refresh generations,
  and stale-response suppression.
- [x] Add the dedicated responsive tab, overview, full lists, metadata details, command bars, and
  originating-window restoration.
- [x] Add the theme-aware constellation preset, ASCII fallback, custom provider validation, and
  resize or color-scheme rerendering.
- [x] Add launcher opening, Inbox capture and review handoff, filtering, refresh, help, and state
  restoration.
- [x] Add isolated model, loader, background, UI, controller, configuration, and API coverage.
- [x] Pass the disposable-vault Home read gate and complete all English and Russian documentation.
- [x] Add confirmed Obsidian-trash deletion to the overview, every full section, and all supported
  vault-search surfaces, with in-place result removal or picker refresh.

## Verification

- `make test`
- `make lint`
- `make helptags`
- `make check`
- `make test-integration TEST_VAULT=nvim-obsidian-para-flow-dev`
- Manual Home review in stock Neovim and the LazyVim development profile
