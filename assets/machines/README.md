# Approved illustrated arcade machines — staged gameplay integration

These six bitmap layers are for the flagship machines, based on the original
approved full-table concept images in the owner's Pinball game project:

| Active flagship table | Fixed layer, flippers and ball removed | Moving left-flipper source (right is horizontally mirrored) |
| --- | --- | --- |
| Astral Orrery | `celestial_orrery.png` | `flipper_celestial.png` |
| Circuit Velocity | `neon_velocity.png` | `flipper_neon.png` |
| Grand Mechanism | `clockwork_mechanism.png` | `flipper_clockwork.png` |

These are original **2D** illustrations, not 3D models. Their 1024x1536
playfield/art coordinates are authoritative for `lib/game/machine_blueprints.dart`.
At runtime the full image is aspect-fitted into `Rect.fromLTWH(0, 80, 400, 600)`
with no crop or tint. Every traced impact wall, flipper hinge, popup target,
shooter launch and drain uses that exact transform. Do not independently scale
individual components or add generic fluorescent line art over the images.

Flipper pivot and geometry are still a *first calibration pass*. This source
does not contain extracted ramp glass layers for proper front/back occlusion,
full target bank scoring, or standalone moving gear sprites for every visible
machine mechanism. The six non-flagship tables remain independently playable
on the existing layouts and old artwork until each receives approved custom
assembled-machine art and physically calibrated geometry.

Owner phone QA: start each flagship table, long-press the SCORE label to toggle
orange wall / green target calibration lines; compare them with the machine
hardware. Check both flippers, shooter lane exit, right drain and both outlanes,
all bumper impact circles, ramp collisions, portal/reaction effects, and ball
visibility/occlusion on curved ramps. Capture actual gameplay screenshots for
acceptance; never mark delivered based on static machine art alone.
