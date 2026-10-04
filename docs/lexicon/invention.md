# Invention

- **Tags:** gameplay, design, implementation
- **Status:** ✅ (DESIGN.md §5.1)
- **Journal:** unlocks in Yellow, the first level that earns one (the yellow pot); page on the Inventions tab
- **Also called:** recipe (stateless), machine (stateful), sticker (how it's drawn)

## Gameplay

Solve some levels and the machine you built becomes an invention: one piece you can use again, priced at all the pieces inside it. Every paint-box level earns a pot of its paint.

## Design

- Solve a level, earn the construct, use it later (DESIGN.md §5.1). An invention costs the pieces inside it, so rankings stay honest.
- Before it's accepted, an invention is run on every combination of input paints; one that only matches the level's cards is refused.
- Earned pots are inventions with no inputs. Every invention keeps the cheapest machine the player made it with, so going back for ★★★ makes it cheaper; where two levels earn the same one (the Black pot in All the Paint and Black, the Short Way; Same Paint in Only the Third Paint and Same Paint), the cheaper machine wins (designer, 2026-10-05).
- From chapter 2 on, every earned pot is in every tray that has the red pot, in the pot slot's fan ([tray](tray.md)).
- The journal's Inventions tab (once the Pattern Book) shows the paint shelf and the invention slots.

## Implementation

`core/invention.gd` packages a machine (`package`) and runs the every-paint check (`works_for_every_paint`); `Progress.add_invention` keeps it. The simulator runs an invention as one table lookup (`Simulator.invention_table`).

## Related

[Piece](piece.md) · [Journal](journal.md)
