# Shift

- **Tags:** gameplay, design, implementation
- **Status:** ✅ two names (designer, 2026-10-05): the term is the algebra's and the code's name; the player sees the critter's name
- **Player word (decided 2026-10-05, not built):** Shift Wheel. It becomes the Player word, and the Gameplay text uses it, when the rename is built (then `.\make words`).
- **Journal:** unlocks in Yellow; page on the Pieces tab (Turn the Wheel fills it at once)

## Gameplay

Shift turns the paint wheel one step: red becomes yellow, yellow becomes blue, and blue becomes red again. Mixed paints turn too: orange becomes green. White and black stay as they are.

## Design

- A hamster in a red, yellow and blue wheel that clicks one notch per drop: the one place outside paint where signal hues appear, because the wheel is the rule it applies.
- With one red pot, Shift makes yellow and blue: why one pot is enough (DESIGN.md §2.4).
- First offered in Yellow (level 2). Turn the Wheel weaves a swatch through it, every row all eight paints in a different order.
- Price 1. Idea from the playtest: toggle-turn the wheel to force a particular turn.

## Implementation

`"shift"` in `core/pieces.gd`; `Paint.shift` in `core/paint.gd`.

## Related

[Critter](critter.md) · [Paint](paint.md) · [Paint card](paint-card.md)
