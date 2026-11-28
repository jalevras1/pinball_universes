# Pinball mechanical candidate packs — 014 through 016

This directory mirrors the **metadata** for three independently generated
asset packs stored in the user's persistent Pinball Universes Library.
It deliberately does **not** activate untested mechanics in the playable game.

| Pack | Devices | PNG animation frames |
| --- | ---: | ---: |
| 014 — chrome rails, slingshots, pop bumper and capture holes | 9 | 13 |
| 015 — six styled ramps, gates, vortexes and spinners | 12 | 40 |
| 016 — moving walls, blockers, underpasses, locks and kickers | 11 | 40 |

The two board-recipe files specify 12 mechanically different experimental
layouts across six art styles (Cosmic, Fantasy, Cyber, Ancient, Ocean, Volcanic).
The existing playable game's Celestial, Neon and Clockwork tables remain
unchanged. These candidate themes are future expansion ideas, not currently
shipped boards.

All sprite geometry is defined in 512 × 512 local pixel space with top-left
origin; scale any drawn sprites, collision outlines and triggers together.
The actual original PNG files remain archived in the corresponding Library
folders `Pinball Universes/Assets/Production Ready Candidates/Batch_014`,
`Batch_015`, and `Batch_016`.

Before importing a candidate: copy its exact source PNGs, register their
Flutter asset directory, verify alpha transparency at gameplay resolution,
implement its state machine and collider behavior, then test ramp transitions,
trigger entrances/exits, flippers, plunger trajectory, drains, multiball,
score consistency, and Android browser frame rate. Do not present these
metadata-only candidate recipes as playable board completions.

The matching `test/mechanical_asset_catalog_test.dart` verifies structural
metadata and layout diversity but cannot validate mechanics or images.
