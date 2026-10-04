# Critter

- **Tags:** gameplay, design, implementation
- **Status:** 🟡 (the art direction is decided, DESIGN.md §7.2; "critter" as a player word, 2026-10-04)
- **Journal:** unlocks in Yellow, with the first critter (Shift); each critter's page is on the Pieces tab
- **Also called:** vat (DESIGN.md §3 working vocabulary)

## Gameplay

Critters are the workshop's little helpers. Each one does one job to paint: paint drips in on its left, it does its job, and the new paint comes out on its right. A critter always does the same thing to the same paint, so once you know it, you can count on it.

## Design

- Every critter is a [piece](piece.md), but not every piece is a critter: Split is plumbing; an invention is a sticker with its name.
- The prototype's critters (`ui/draw_kit.gd`, DESIGN.md §7.2):

  | Critter | In → out | What it does | How it looks |
  |---|---|---|---|
  | Red pot | 0 → 1 | Red, every time its tube is free | A sleepy clay pot that burps |
  | [Mix](mix.md) | 2 → 1 | Everything in either paint | A tub that stirs with a spoon |
  | [Filter](filter.md) | 2 → 1 | Only what both paints share | A fussy, heavy-lidded tub with a sieve that shakes |
  | [Invert](invert.md) | 1 → 1 | The opposite paint | A tub that flips like a pancake |
  | [Shift](shift.md) | 1 → 1 | Turns the wheel one step: red → yellow → blue → red | A hamster in a red, yellow and blue wheel |
  | Catch pot | 1 → 0 | Swallows every drop and remembers the last few | A pale glazed jar looking back up its tube (out of the trays for now) |

- Earned pots (yellow, blue and the rest) are inventions drawn as the clay pot holding their own paint.
- Glyph dots show a critter's rule as it fires: Shift turns the dots one notch; Invert empties the filled dots and fills the empty ones.
- Art: chunky, toy-like vector art drawn in code; each critter has a signature animation. Faces must stay out of the way on big machines.
- More personality (playtest): more whimsical, less factory-like. Some critters could be real tools (like the red pot); the hamster wheel is the vibe; Invert could be a gerbil that shaves the input off a black paint.
- The workshop cast (small animals and a master who hands out commissions) is a separate idea, not decided (DESIGN.md §7.2, §12).
- New critters to come: the prism (one paint in, its three primaries out), and from the algebra review, Delay, If White and Slate. Each needs a character and animations, the known cost of this style.

## Implementation

`core/pieces.gd`: one entry per piece in `TABLE` (name, ports, operation, cost, `look`). Adding a two-input vat is one line there; the generic `tub` look in `ui/draw_kit.gd` draws it. A new piece also needs a line in `PIECE_NOTES` in `tools/algebra_check.gd`.

## Related

[Piece](piece.md) · [Paint](paint.md) · [Journal](journal.md)

## Open questions

- Noun names: Mix, Filter, Invert and Shift are verbs; they stay as they are for now (tagged temporary).
