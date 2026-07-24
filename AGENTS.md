# Repository Guidelines

## Project knowledge

- **The single source of truth is always the documentation repository in Obsidian** (the Russian second-brain): [obsidian para flow](</Users/jjuchara/Library/Mobile Documents/iCloud~md~obsidian/Documents/obsidian_jjuchara/1. Projects/obsidian para flow/00. obsidian para flow.md>). Open it in Obsidian with [obsidian para flow](obsidian://open?vault=obsidian_jjuchara&file=1.%20Projects%2Fobsidian%20para%20flow%2F00.%20obsidian%20para%20flow). All thinking, planning, ideas, decisions, design, manual-testing evidence, and roadmap live and are maintained there.
- **This git repository stores the code-adjacent English contracts required to use, maintain, verify, and release the plugin** — for example README, Vim help, CHANGELOG, ARCHITECTURE, CONTRIBUTING, DECISIONS, LICENSE, and RELEASE_CHECKLIST. Product thinking, speculative planning, ideas, and manual evidence remain only in Obsidian; do not create English mirrors of the second brain here.
- **Read `00. obsidian para flow.md` and the relevant files under `1. Projects/obsidian para flow/` before planning substantial work** — that is where the authoritative project state lives.
- After meaningful code or behavior changes, update the affected documents in the Obsidian source of truth (Russian), and refresh the repository's release-facing files (English) when the change is user-visible.

## Current state

This is a published Neovim plugin at `v0.6.1`. It supports Neovim 0.10–0.12 and uses the official Obsidian CLI as its only process boundary. The current public behavior, architecture, dependencies, build commands, and verification workflow are documented in README, Vim help, ARCHITECTURE, CONTRIBUTING, and RELEASE_CHECKLIST; keep those contracts synchronized with the implementation and the canonical Obsidian project.

## Change discipline

Keep changes focused and add automated coverage for behavior. Record user-visible changes and durable technical decisions in the repository's English-language changelog and decision log. Keep the corresponding Obsidian project documentation in Russian.
