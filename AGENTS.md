# Repository Guidelines

## Project knowledge

- **The single source of truth is always the documentation repository in Obsidian** (the Russian second-brain): [Плагин для PARA Обсидиан](</Users/jjuchara/Library/Mobile Documents/iCloud~md~obsidian/Documents/obsidian_jjuchara/1. Projects/obsidian para flow/Плагин для PARA Обсидиан.md>). Open it in Obsidian with [Плагин для PARA Обсидиан](obsidian://open?vault=obsidian_jjuchara&file=1.%20Projects%2Fobsidian%20para%20flow%2F%D0%9F%D0%BB%D0%B0%D0%B3%D0%B8%D0%BD%20%D0%B4%D0%BB%D1%8F%20PARA%20%D0%9E%D0%B1%D1%81%D0%B8%D0%B4%D0%B8%D0%B0%D0%BD). All thinking, planning, ideas, decisions, design, manual-testing evidence, and roadmap live and are maintained there.
- **This git repository stores the code-adjacent English contracts required to use, maintain, verify, and release the plugin** — for example README, Vim help, CHANGELOG, ARCHITECTURE, CONTRIBUTING, DECISIONS, LICENSE, and RELEASE_CHECKLIST. Product thinking, speculative planning, ideas, and manual evidence remain only in Obsidian; do not create English mirrors of the second brain here.
- **Read `Плагин для PARA Обсидиан.md` and the relevant files under `1. Projects/obsidian para flow/` before planning substantial work** — that is where the authoritative project state lives.
- After meaningful code or behavior changes, update the affected documents in the Obsidian source of truth (Russian), and refresh the repository's release-facing files (English) when the change is user-visible.

## Current state

This is a published Neovim plugin at `v0.7.0`. It supports Neovim 0.10–0.12. Structured vault reads and all vault mutations use the official Obsidian CLI; search providers may scan files directly, and the built-in content-search fallback additionally invokes `rg` without a shell. The current public behavior, architecture, dependencies, build commands, and verification workflow are documented in README, Vim help, ARCHITECTURE, CONTRIBUTING, and RELEASE_CHECKLIST; keep those contracts synchronized with the implementation and the canonical Obsidian project.

## Change discipline

Keep changes focused and add automated coverage for behavior. Record user-visible changes and durable technical decisions in the repository's English-language changelog and decision log. Keep the corresponding Obsidian project documentation in Russian.

## Mandatory documentation gate before every commit

**Do not create or amend a commit until its implementation and documentation are synchronized.** Immediately before every commit or amend:

1. Inspect the complete staged and unstaged diff and classify its effect on public behavior, configuration, commands, Lua API, architecture, verification, release state, decisions, manual evidence, and roadmap.
2. Update the affected Russian documents in the canonical Obsidian project first. Behavior, design, decisions, manual evidence, and roadmap must not be left only in the code repository or in chat.
3. Update every affected English code-adjacent contract in the same change: README and Vim help for user behavior; ARCHITECTURE and DECISIONS for durable technical contracts; CONTRIBUTING and RELEASE_CHECKLIST for verification or release workflow; CHANGELOG for user-visible changes.
4. Re-read the resulting code and documentation diff together, run `make check` and `git diff --check`, and verify that the public command and Lua API documentation test passes.
5. Commit code and its required documentation together. A code-only commit is allowed only when the diff has no documentation impact; make that conclusion explicitly after checking the categories above rather than assuming it.

This gate applies to implementation commits, fixes, refactors, tests that change the verification contract, and commit amendments. Release evidence discovered only after publication may use a follow-up docs-only commit because it did not exist at release-commit time.
