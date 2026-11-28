# Pinball Universes — Batch 023: Brass Switchyard dual elevated tunnels

**Board:** Brass Labyrinth, Clockwork Empire (existing ninth playable table).

Unlike a static wall or second recolored ramp, the switchyard has two physically
independent track routes behind alternating retracting gate shutters.

* 6.4-second periodic switching: left open for 3.2 s, then right open for 3.2 s.
* Closed gate physically reflects incoming balls through the real swept rail
  collider and earns 125 points only for a hit (with per-ball contact cooldown).
* Entering the open gate requires an actual DOWNWARD sweep across y=375 and
  matching x-coordinate, not merely hovering near painted artwork.
* Once inside, each ball travels along an exact 85-waypoint curve, at 310
  logical pixels/s, suspended over the lower playfield. The original lower
  bumpers and rails cannot cause ghost collisions during raised travel.
* Left exit (94,484): 650 points, velocity (-185,255).
* Right exit (304,484): 850 points, velocity (175,260).
* Each exit has a 0.9 s recapture cooldown. Score awarded on completion only.
* Two new developer test buttons inject moving balls through authentic sensors
  and exercise actual physics; no fake point injection or scene restart.
* Five RGBA PNGs: full-field precision overlay, two energized route overlays,
  and gate-open / gate-closed physical hardware.

All art coordinates are 400x760 playfield units, rasterized at 2x (800x1520)
for the track and 180x120 for gates. Both physical routes match the `manifest`
source coordinates and the Dart paths within <0.00011 game units.

`qa/mechanism_preview.png` is a DESIGN/ALIGNMENT PREVIEW, not a screenshot of
compiled Flutter gameplay. Do not announce gameplay QA until live or compiled
browser verification, Flutter analysis/tests and release build are successful.