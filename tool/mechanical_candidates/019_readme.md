# Batch 019 — collision-aligned metallic slingshots

The Astral Orrery's two original, functional rail triangles now have dedicated
top-down 2D metallic overlays. Each has idle and high-energy contact artwork
fitted by a full-resolution affine transform to the original three corners,
exported as independent 96×112 RGBA PNGs.

Real rail geometry remains unchanged:
- Left [108,518] [158,574] [128,604]; first edge is a kicker.
- Right [258,518] [223,574] [252,604]; first edge is a kicker.
- Left sprite destination Rect.fromLTWH(98,508,96,112).
- Right sprite destination Rect.fromLTWH(210,508,96,112).

Existing contact collision, velocity impulse, scoring and drain behavior are
unchanged. When a real kicker collision awards the original 100 points, the
corresponding art flashes for 0.16 seconds. A missing asset falls back to the
existing procedural metal triangle, never leaving an invisible physical wall.

Files originate from the user's persistent Pinball Universes Library Batch 014
and are archived as authoring masters in Library Batch 019. Tests verify
bundling, dimensions, RGBA transparency and unchanged bounce/score path.
This is NOT a new playable board or tested mobile-device performance claim.
