# Product

## Register

product

## Users

Terminal-first knowledge workers who use Neovim for focused writing and Obsidian as their durable
PARA vault. During review they need to understand the current note, available action, queue state,
and safety outcome without leaving the keyboard or decoding plugin-specific decoration.

## Product Purpose

Capture notes into an Obsidian Inbox and process them into Projects, Areas, Resources, or Archives
without leaving Neovim. Success means a fast, legible queue workflow in which mutations are
predictable, reversible where possible, and never hide conflicts or partial failures.

## Brand Personality

Focused, native, trustworthy. The interface should feel like a polished part of the user's editor:
quiet during reading, explicit during decisions, and precise when reporting risk or recovery.

## Anti-references

- Oversized empty modal surfaces that make one note feel lost inside the screen.
- Uncontrolled transparent or glass-like panels that allow dashboards and lower buffers to compete
  with text; subtle theme-derived blending is acceptable when content remains dominant.
- Decorative dashboards, novelty typography, or color that does not communicate state.
- Mouse-first controls or hidden actions that weaken the terminal workflow.
- Custom interaction patterns where standard Neovim, `vim.ui`, or provider behavior is clearer.

## Design Principles

1. Keep the current note dominant and the queue context compact.
2. Make destructive choices and recovery state unmistakable before mutation.
3. Use familiar Neovim and provider conventions so the interface disappears into the task.
4. Earn every row: prefer concise headers, aligned actions, and useful content over empty space.
5. Respect the active theme while guaranteeing legibility and visual separation.

## Accessibility & Inclusion

All workflows are keyboard-complete and usable without optional providers. Meaning is never carried
by color alone; labels and keys remain visible. Theme-derived colors must retain readable foreground
and background separation, and the UI must remain functional in stock Neovim, transparent themes,
and common terminal sizes without motion-dependent feedback.
