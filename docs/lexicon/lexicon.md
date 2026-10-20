# Lexicon

The game's vocabulary, one file per term; this page is the index. One catch-all collection: design words, code words and the words players meet all live here, told apart by tags. The terms tagged *gameplay* form the player's lexicon, which the [journal](journal.md) shows on its Words tab.

## Tags

- **gameplay**: the player meets the word. Its **Gameplay** section is the text the journal shows, so it's written for players: short, in paint, never bits or numbers for colors, readable by an 8-year-old. After editing one, run `.\make words` (it rewrites `data/words.json`, which the game ships; a test fails if they drift apart).
- **design**: a word of the design (DESIGN.md, playtest notes, design talk).
- **implementation**: a word of the code. Its **Implementation** section is a reminder for us and never appears in the game.
- **temporary**: a placeholder name we keep on purpose for now. Use it, but expect it to change (the tray).

A piece has two names (designer, 2026-10-05; built 2026-10-05): the term is the operation's name, used by the algebra, the code and the design (Mix, Filter, Invert, Shift, Split, Red); its **Player word** is the critter's name, the only one in player-facing text (Mixing Tub, Sieve, Flip Pan, Shift Wheel, Split, red pot).

A term carries every tag that fits.

## A term's file

A small header, then sections in this order, any left out when there's nothing to say:

- **Tags**, as above.
- **Status**, with DESIGN.md's markers: ✅ decided, 🟡 working (in use, not confirmed), ❓ no settled word yet. A decision made here goes into DESIGN.md too.
- **Player word** (gameplay terms): the word as the player sees it, when it differs from the term.
- **Journal** (gameplay terms): "unlocks in <Level name>", the level whose solve unlocks the word on the Words tab (matched by name, so a renamed level needs this line updated), then "page on the <Tab> tab" if it has a fuller page.
- **Also called**: other words for it, including old ones, so older notes still lead somewhere.
- **Gameplay**: what the player is told (the journal's Words entry).
- **Cases** (a piece or invention that takes two paints): its case rows on its journal page, 3 to 6 lines of `- Orange + Red → Yellow: the red they share washes out.`, one per kind of pair, each with a short reason in the Gameplay voice. `.\make words` writes them into `data/words.json`; the journal test checks each answer against the piece or invention.
- **Design**: how we think about it.
- **Implementation**: where it lives in the code.
- **Related**, **Open questions**.

Files are named after the term in lower-case kebab-case (`paint-card.md`) and listed below.

## Terms

| Term | Tags | Status | In short |
|---|---|---|---|
| [Any Paint?](any-paint.md) | gameplay, design, implementation | 🟡 | An invention: one paint in, black if there is any paint, white if none. |
| [Brown](brown.md) | gameplay, design | ✅ | The paint that is not one of the eight: mixing all three primaries makes black here, and brown's hues dress the interface. A word on the Paint tab. |
| [Cloth](cloth.md) | gameplay, design, implementation | 🟡 | The picture a machine weaves on the loom. |
| [Contrast](contrast.md) | gameplay, design, implementation | ✅ | An invention: mixes two paints, but what they share washes out. Player word: Extreme Mix. |
| [Critter](critter.md) | gameplay, design, implementation | 🟡 | A piece drawn as a character that does one thing to paint. |
| [Filter](filter.md) | gameplay, design, implementation | ✅ | Keeps only what two paints share. Player word: Sieve. |
| [Historical note](historical-note.md) | design, implementation | 🟡 | A chapter's reward for a full quilt: a snapshot of how looms led to machines that follow cards, a tag on the quilt on Cloths. |
| [Invert](invert.md) | gameplay, design, implementation | ✅ | Turns a paint into its opposite. Player word: Flip Pan. |
| [Invention](invention.md) | gameplay, design, implementation | ✅ | A machine the player built, kept as one piece to use again. |
| [Is It Black?](is-it-black.md) | gameplay, design, implementation | 🟡 | An invention: one paint in, black only if it is black. |
| [Journal](journal.md) | gameplay, design, implementation | ✅ | The player's book of everything learned, made and woven. |
| [Loom](loom.md) | gameplay, design, implementation | 🟡 | Weaves the machine's paint into the cloth, one stitch per tick. |
| [Lost Levels](lost-levels.md) | design | ✅ | The hidden extra campaign where levels that leave the campaign go. |
| [Missing From Either](missing-from-either.md) | gameplay, design, implementation | 🟡 | An invention: whatever one paint or the other lacks, the opposite of the Sieve. |
| [Mix](mix.md) | gameplay, design, implementation | ✅ | Gives everything in either of two paints. Player word: Mixing Tub. |
| [Paint](paint.md) | gameplay, design, implementation | ✅ | One of the eight paints, from white (none) to black (all three primaries). |
| [Paint card](paint-card.md) | gameplay, design, implementation | ✅ | The cheat sheet of the eight paints, up over the workshop. |
| [Pattern card](pattern-card.md) | gameplay, design, implementation | ✅ | Holds a picture as paint and lets it out one drop at a time. |
| [Piece](piece.md) | gameplay, design, implementation | 🟡 | Anything put in the workshop from the tray; its cost counts toward the Cost score. |
| [Quilt](quilt.md) | gameplay, design, implementation | ✅ | A chapter's cloths sewn together. |
| [Red pot](red-pot.md) | gameplay, design, implementation | ✅ | The one pot of red paint every other paint starts from. |
| [Same Paint](same-paint.md) | gameplay, design, implementation | 🟡 | An invention: what two paints agree on, what both have and both lack. |
| [Shift](shift.md) | gameplay, design, implementation | ✅ | Turns the paint wheel one step. Player word: Shift Wheel. |
| [Shuttle](shuttle.md) | gameplay, design, implementation | 🟡 | The little wooden boat that marks the stitch, or the card drop, coming next. |
| [Split](split.md) | gameplay, design, implementation | 🟡 | Copies one drop into two; free. |
| [Stars](stars.md) | gameplay, design, implementation | ✅ | One to three per level: woven, few pieces, fewest pieces. |
| [Stitch](stitch.md) | gameplay, design, implementation | 🟡 | One square of a cloth, woven from one drop. |
| [Third Paint](third-paint.md) | gameplay, design, implementation | 🟡 | An invention: the opposite of a mix, whatever neither paint has. |
| [Thread](thread.md) | gameplay, design | ✅ | A line of stitches in a cloth: a row across or a column down. |
| [Tick](tick.md) | gameplay, design, implementation | 🟡 | One beat of the workshop clock. |
| [Tray](tray.md) | gameplay, design, implementation, temporary | 🟡 | The shelf of pieces along the bottom of the workbench. |
| [Tube](tube.md) | gameplay, design, implementation | ✅ | The glass tube that carries paint from one piece to the next. |
| [Workbench](workbench.md) | gameplay, design, implementation | ✅ | Where the player builds a machine. Player word: Workshop. |

## Still to write

Catch pot, drop, design card, opposite, primary, glyph dots, machine, chapter, level, guided level (design: a level whose hand teaches what it brings in, DESIGN.md §5.7; replaced "tool introduction", 2026-10-05), peek, profile (gameplay, design: a local save slot with a critter badge and an optional name, the anonymous, local, offline mode, DESIGN.md §9, 2026-10-05; not built).
