# Shift

- **Tags:** gameplay, design, implementation, temporary (a verb; noun names are wanted but deferred)
- **Status:** 🟡
- **Journal:** unlocks in Yellow; page on the Pieces tab (Turn the Wheel fills it at once)

## Gameplay

Shift turns the paint wheel one step: red becomes yellow, yellow becomes blue, and blue becomes red again. Mixed paints turn too: orange becomes green. White and black stay as they are.

## Design

- A hamster in a red, yellow and blue wheel that clicks one notch per drop: the one place outside paint where signal hues appear, because the wheel is the rule it applies.
- With one red pot, Shift makes yellow and blue: why one pot is enough (DESIGN.md §2.4).
- First offered in Yellow (level 2). Turn the Wheel weaves one thread of all eight paints through it.
- Price 1. Idea from the playtest: toggle-turn the wheel to force a particular turn.

## Implementation

`"shift"` in `core/pieces.gd`; `Paint.shift` in `core/paint.gd`.

## Related

[Critter](critter.md) · [Paint](paint.md) · [Paint card](paint-card.md)
