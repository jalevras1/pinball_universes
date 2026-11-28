# Batch 021 — Moonfall Sanctuary Moonbridge Ramp

The Moonbridge is a new **functioning elevated ramp**, not merely another
image overlay. The ball must approach the entrance at (290, 518) while
traveling upward. The physics model captures the ball within 16 logical
units and moves it along the same 97-point spline used to draw the artwork.

- Target board: Moonfall Sanctuary (Celestial Realms, variant 1).
- Source artwork: original 1200x2280 transparent PNGs (idle/active).
- Bundled mobile assets: 600x1140 transparent palette PNGs; two frames.
- World coordinates: 400x760 units, sprite scaled to that exact area.
- Travel speed: 470 world-units/second over a ~401.4-unit curved elevated lane.
- Exit at (78, 332), initial velocity (-145, 260).
- A **700-point award occurs only on reaching the end** of the track.
- A 1.1-second recapture cooldown prevents exit/entry loops.
- An elevated ball does not collide with the lower rails and bumpers.
- All original nine tables and their existing launch, flipper and drain
  mechanics remain in place.

The original assets, source-generation script, preview, collider coordinates
and QA records are stored in the persistent Library:

`Pinball Universes/Assets/Production Ready Candidates/Batch_021`

CI tests cover: exact waypoint equality against the authoring manifest,
PNG inclusion and dimensions, upward-only entry, cooldown, timestep
independence, completion scoring, non-interference with other boards, and
continuation of the normal game afterward.

This integration is still a development candidate until the compiled
mobile-viewport playtest and physical device acceptance checks pass.
