# Home Design

## Status

Accepted and implemented on 2026-07-22. Home is the first product workflow after the released
`v0.1.x` Inbox MVP.

## Purpose

Home is a navigation-first PARA dashboard for keyboard-first use. It summarizes the configured
Inbox and PARA roots, opens selected Markdown notes in a new tab without replacing the originating
repository, supports confirmed movement of the selected note to Obsidian trash, and hands off to
the existing Inbox capture and review workflows without evaluating Dataview or Tasks queries.

Daily notes, task management, metadata editing, Markdown body preview, multiple vault profiles,
and configurable non-PARA categories are outside this workflow.

## Data contract

All data and the explicit trash action go through the official Obsidian CLI. Home never repairs or
writes metadata, and it has no permanent-delete path.

- Inbox shows the total and oldest notes in FIFO order.
- Projects includes notes carrying the `projects` tag and shows status, area, and deadline when
  present. Full results are grouped by status using the configured status order.
- Areas includes notes carrying the `area` tag with `listShow: true` and groups nested entries by
  folder.
- Resources includes notes carrying the `resources` tag, shows area, orders the overview by recent
  modification, and groups full results by area.
- Archives includes every Markdown note under the configured Archives root, orders the overview by
  `archived` with modified-time fallback, and groups full results by their first archive folder.
- Missing optional metadata remains visible as missing data. It is never inferred or mutated.

The loader lists each configured folder, validates every returned path, and fetches properties and
file information with at most six concurrent note requests. Sections resolve independently. A
generation token discards stale callbacks after refresh or closure.

## Information architecture

Home opens in a dedicated tab so the originating window and layout remain intact. Wide screens use
an asymmetric overview: Inbox is compact, Projects is dominant, and Areas, Resources, and Archives
form a quieter secondary row. Medium screens use two columns. Narrow screens show one active
section at a time.

The overview shows up to `home.preview_limit` notes per visible section. `p`, `a`, `r`, and `x`
open full grouped lists. A wide full-list view adds a metadata panel with path, category, status,
area, dates, and archive details. It never reads the Markdown body while navigating.

Opening a note uses launcher behavior: Home closes and the real file buffer opens in a new tab.
Missing files and load failures leave Home open and trigger a refresh.

## Interaction contract

| Key | Action |
| --- | --- |
| `<leader>oh` | Open or focus Home. |
| `j` / `k`, arrows | Move within the active section. |
| `<Tab>` / `<S-Tab>` | Move between sections. |
| `p` / `a` / `r` / `x` | Open a full PARA list. |
| `/` | Filter the current full list by name or path. |
| `<Enter>` | Open the selected note in a new tab. |
| `d` | Confirm and move the selected note to Obsidian trash. |
| `n` | Close Home and start Inbox capture. |
| `i` | Close Home and start Inbox review. |
| `R` | Discard cached section state and reload. |
| `<Esc>` | Clear a filter or return to the overview. |
| `?` | Show the keyboard summary. |
| `q` | Close Home and restore the origin. |

The command bar always exposes the actions required by the current mode. Meaning is never carried
by color alone. Deletion is available in both the overview and full sections, ignores duplicate
keypresses while pending, and removes the note from the current model only after CLI success.

## Visual system

Home uses a restrained, theme-derived palette. The active theme supplies the base surface and one
accent through `Special` or `Identifier`; purple is the fallback. Selected rows, section focus,
loading, empty, and error states use separate public highlight groups.

The default `constellation` background places sparse crystals, points, and connecting strokes in
unused space. It is static, low contrast, rebuilt after resize or color-scheme changes, and falls
back to ASCII when the terminal cannot display the Unicode crystal at one cell. Panels overwrite
the background, so decoration never competes with data.

`home.background.provider` accepts `false`, `"constellation"`, or a callback. A callback receives
`width`, `height`, `background`, `colors_name`, and `unicode`, then returns fragments with one-based
`row`, `col`, and `text`. A custom provider fully replaces the preset. Invalid fragments are
ignored, coordinates and text are clipped, callback errors degrade to a clean background, and the
dashboard remains usable.

## Accessibility and failure states

- Home is keyboard-complete in stock Neovim and has no runtime plugin dependency.
- Loading uses textual skeleton rows rather than motion.
- Empty sections say `No notes`; filter misses say `No matching notes`.
- A failed section reports locally and does not hide successful sections.
- Theme-derived foreground and surface groups retain explicit separation in transparent themes.
- Resize and color-scheme changes rerender the same state without restarting CLI work.
