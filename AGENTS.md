# Repository Guidelines

## Project knowledge

- **The single source of truth is always the documentation repository in Obsidian** (the Russian second-brain): [obsidian para flow](</Users/jjuchara/Library/Mobile Documents/iCloud~md~obsidian/Documents/obsidian_jjuchara/1. Projects/obsidian para flow/00. obsidian para flow.md>). Open it in Obsidian with [obsidian para flow](obsidian://open?vault=obsidian_jjuchara&file=1.%20Projects%2Fobsidian%20para%20flow%2F00.%20obsidian%20para%20flow). All thinking, planning, ideas, decisions, design, manual-testing evidence, and roadmap live and are maintained there.
- **This git repository stores release information exclusively** — only what a plugin consumer and the release itself require (for example README, CHANGELOG, LICENSE, RELEASE_CHECKLIST). Do not add second-brain documentation here; keep the repository to the minimum necessary. Repository-facing text stays in English.
- **Read `00. obsidian para flow.md` and the relevant files under `1. Projects/obsidian para flow/` before planning substantial work** — that is where the authoritative project state lives.
- After meaningful code or behavior changes, update the affected documents in the Obsidian source of truth (Russian), and refresh the repository's release-facing files (English) when the change is user-visible.

## Current state

This is a newly initialized Neovim plugin project. Define the MVP, architecture, supported Neovim versions, dependencies, build commands, and verification workflow in the repository before adding repository-specific rules for them.

## Change discipline

Keep changes focused and add automated coverage for behavior. Record user-visible changes and durable technical decisions in the repository's English-language changelog and decision log. Keep the corresponding Obsidian project documentation in Russian.
