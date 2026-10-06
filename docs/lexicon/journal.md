# Journal

- **Tags:** gameplay, design, implementation
- **Status:** ✅ (renamed, 2026-10-04); its tabs ✅ and built (DESIGN.md §5.7)
- **Journal:** unlocks in One Pot of Red
- **Also called:** Swatch Book (the old name), compendium, knowledge base (playtest notes), Pattern Book (the screen it replaced, now the Inventions tab)

## Gameplay

Your journal keeps everything you've learned and made: the paints, how the loom keeps time, what every piece does, your inventions, the cloths you've woven and your best scores. Its pages fill as you play.

## Design

- **The player's own record:** pages fill from what the player's machines actually did, like a sticker album. Play teaches the rules first; the journal is a reward and a reference.
- **Tabs, as the player reads them:** Paint · Loom · Pieces · Inventions · Cloths · Scores · Words.
  - **Paint** and **Loom:** short articles, the Gameplay text of the words on that tab ([paint](paint.md), [paint card](paint-card.md); [loom](loom.md), [stitch](stitch.md), [shuttle](shuttle.md), [tick](tick.md), [tube](tube.md), [thread](thread.md)).
  - **Pieces:** a page per [piece](piece.md) with a frame for every paint it can be given.
  - **Inventions:** the paint shelf and the [invention](invention.md) slots (the old Pattern Book).
  - **Cloths:** a picture gallery, a slot per level, empty until woven, each chapter's [quilt](quilt.md) beside its cloths.
  - **Scores:** a scoreboard of the best per level ([stars](stars.md), best Pieces, best Ticks).
  - **Words:** the player's lexicon, every term tagged *gameplay* here: its word, a small picture and its Gameplay text, with a button to its fuller page, if it has one.
  - Rewards and achievements: later, a vibe for now.
- **Words unlock when their level is solved** (designer, 2026-10-04); each term's "Journal:" line names the level. Every entry exists from the start; ones not found yet stay visibly locked, an empty frame naming the level, so the player sees there's more to find.
- **New in your journal:** after the success panel, a card shows what the solve brought (its words, and the frames the runs filled): a stepping stone into the rest of the campaign.
- A piece's page is a level reward: its text unlocks when the level that brings the piece in is solved (designer, 2026-10-04).
- Each piece's page has a frame per paint, filled the first time the player's own machine does that, in any run; a thread level fills a whole page at once. Mix and Filter's table fills both ways at once. Rebuilding a critter earns a page on what it's made of (not built yet).
- **Peek** (designer, 2026-10-04: select, then tap): the journal sits by the trash on the [tray](tray.md). Select a piece (or pick one up), tap the journal, and it opens at that piece's page, showing only what the player knows so far. It replaces the long-press idea.
- **Tool introductions** (the cutscene-like beats the playtest asked for) are kept in the journal; the level list links to them (to try; not built).
- The [paint card](paint-card.md) stays a separate cheat sheet; the Paint page is the longer read.

## Implementation

- `ui/journal.gd`: the screen, opened by `main.gd` from the level select (book button, `book` key) and by the workbench over the bench (`Workbench.open_journal`, the `PEEK` rect and the `peek` key). Keys in the `Journal` group of `ui/keys.gd`. `Journal.picture` draws each word's small picture; `DrawKit.cloth` and `DrawKit.quilt` the Cloths tab.
- `ui/journal_news.gd`: "New in your journal", shown by `Workbench.show_news` after the success panel.
- Words: `.\make words` (`tools/make_words.gd`, parsing in `tools/lexicon.gd`) writes `data/words.json` from the gameplay terms here; `core/words.gd` reads it and says what's unlocked (`Progress.is_solved` of the word's level). `tests/test_journal.gd` fails if the file and the lexicon drift apart.
- Frames: the simulator lists each tick's pieces at work (`Simulator.fired`); the workbench hands them to `Progress.learn`, saved as `"seen"` (piece kind → `Progress.seen_key` of its inputs; save version 2).
- `.\make shot journal <png> --tab=<tab>` for self-check screenshots (see CLAUDE.md).

## Related

[Paint](paint.md) · [Piece](piece.md) · [Cloth](cloth.md) · [Quilt](quilt.md) · [Paint card](paint-card.md) · [Stars](stars.md)

## Open questions

- Tool introductions: their words, and where the level list's links sit.
