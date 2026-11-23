# Staged illustrated-machine pass — QA / limitations

Date: 2026-11-23. Source base: `chatgpt-pinball-development`
at `0dc54ea1e01c9a6deb83d0c110f74fe7542425ac`.

## Completed in source candidate

- Three original full arcade machine concepts used as layout references rather
  than background wallpapers. Fixed images retain all the ramps and hardware,
  while painted balls and flippers were removed before the interactive overlay.
- Three new transparent animated flipper sprites in the matching themes.
- Explicit image-space coordinates for physical guard rails, major ramps,
  slingshots, pop targets, hero mechanisms, shooter, flipper pivots, and drains.
- Unified aspect-preserving image-to-physics transform for flagship machines.
- Core game now selects assembled machine art, geometry, and flipper rendering
  for Astral Orrery, Circuit Velocity, and Grand Mechanism only.
- Existing other six boards remain on their previously playable code path.
- Long-press HUD score to display temporary collider calibration overlay.

## Required validation before development branch merge

1. `flutter pub get`, `dart format --output=none --set-exit-if-changed .`,
   `flutter analyze`, `flutter test`, `flutter build web --release`.
2. Browser / Android phone playtest: initial image loading, correct visual
   side walls and ramps, flipper artwork angle and hitboxes, bumper circles,
   shooter exit, drains, multiball behavior, HUD, performance and tap control.
3. Geometry trace review while calibration overlay is enabled: every visible
   hardware wall must be in the correct position and never cause an invisible
   obstacle; revise map values based on actual screenshots.
4. Layered ramp glass/occlusion and animation of signature central mechanism.
   The first pass uses full fixed art, so the ball can render visually over
   some raised ramps; this must be addressed before premium release.
5. All nine boards ultimately need unique artwork *and* unique geometry, not
   merely shared universe artwork. Six additional layouts are not complete.

## Status

**UNVERIFIED source candidate.** No Flutter SDK in the authoring environment,
so no analyzer, unit test, release build, or owner phone playtest passed here.
This branch must not be merged into the protected playable development baseline
or reported as installed until CI and physical gameplay checks pass.

Additional confirmed checks: `git diff --check` produced no whitespace errors;
ImageMagick found all three fixed playfields at 1024x1536 RGB and all three
flipper layers at 2172x724 RGBA, with nontrivial transparent area. The proposed
new GitHub branch could not be created by the connected app: GitHub returned
HTTP 403 `Resource not accessible by integration`. A direct Git push from this
environment also lacked authenticated credentials. Therefore the live GitHub
repository was **NOT** changed; save this complete source candidate privately
until the owner resolves GitHub write authorization and Flutter tests can run.
