# Historical note

- **Tags:** design, implementation
- **Status:** 🟡 (shape decided by the designer, 2026-10-18; texts a first draft, to improve in a later round)
- **Also called:** a note from history (what "New in your journal" calls it), the quilt's tag

## Design

- A chapter's reward for finishing: one snapshot of how looms led to machines that follow cards (DESIGN.md §4, §5.7), unlocked when the chapter's quilt is full, so it never blocks. Playtest R3 asked for it.
- It hangs from the quilt on the Cloths tab as a paper tag on a string: dashed until the quilt is full ("Sew in every cloth to read this note."), then the note's picture, year and title. A tap or Enter opens the note over the page; any tap, Back or an arrow puts it away. The solve that fills the quilt announces it in "New in your journal" ("A note from history: The Paper Strip"), and the book opens it.
- 3 or 4 sentences in the game's voice (paint and thread, never bits or binary) and one picture drawn in code from wood, paper, thread and ink, never a paint's hue.
- The line-up keeps the dates in order and fits each chapter's idea: Bouchon's paper strip (1725), Falcon's cards on a chain (1728), Jacquard's loom (1804), the woven portrait (1839); for chapters still to come, provisionally Lovelace (1843), Hollerith's sorting box (1890), one open, the Difference Engine No. 2 built in 1991. The drafts and their fact checks are in `levels/level-text.md`, "Historical notes".
- Not a word on the Words tab (yet): it is a reward with a page of its own, not vocabulary.

## Implementation

Each chapter's `note` in `levels/index.json` ({title, year, picture, text}), carried on its levels as `Level.chapter_note`. `Journal.note_open` (a full quilt, from the solves; no save data) decides it; `ui/journal.gd` draws the tag and the open note, `DrawKit.history_picture` the pictures (`HISTORY_PICTURES` lists them), and the workbench adds the "note" row to "New in your journal" on the solve that fills the quilt. The journal test checks every chapter has one, 3 or 4 sentences long, free of bits and colors.

## Related

[Quilt](quilt.md) · [Journal](journal.md) · [Pattern card](pattern-card.md)
