# Paint card

- **Tags:** gameplay, design, implementation
- **Status:** ✅ (the name, 2026-10-04); the card itself 🟡 (DESIGN.md §9.1)
- **Journal:** unlocks in One Pot of Red, where the Paints button is from the start (designer, 2026-10-04); page on the Paint tab
- **Also called:** color card

## Gameplay

The paint card shows all eight paints at a glance. Red, yellow and blue sit at the corners, each mix sits between the two paints it's made of, black is in the middle and white sits apart. Opposites face each other across black. Tap Paints to put it up or away.

## Design

- A cheat sheet, not an article: one look and the player has the answer. The journal's Paint page tells the same rules at length, to read and understand. The overlap is on purpose.
- Laid out as a mixing triangle in the glyph dots' places. Two lessons come without text: opposites face each other across black along dashed lines (Invert jumps across), and Shift turns the triangle one corner clockwise.
- Not modal: the workbench keeps working around it. It clears the middle row, where a single card's machine sits, and stays up from level to level.
- Came from the playtest (2026-10-04): testers asked why red, yellow and blue make black and how the dark paints are made.
- ✅ **Working pieces out on the card** (designer, 2026-10-05; not built): small arrows around the triangle (red → yellow → blue, and orange → green → purple with them), in ink, never a signal hue, so Shift can be read off the card too. Each piece's journal page gets a line on using the card for it: Mix (where two paints meet: the edge between two corners, black once all three are in), Invert (straight across black along the dashed line), Shift (one arrow on). The line unlocks with the page.

## Implementation

`ui/paint_card.gd`, put up by the workbench's Paints button (left of Undo) or the P key; a tap on the card, the button, P or Back puts it away. Whether it's up is saved with the settings (`Keys.paints`, `user://chromaton_settings.json`). `.\make shot <level> <png> --paints` shows it.

## Related

[Paint](paint.md) · [Journal](journal.md) · [Workbench](workbench.md)
