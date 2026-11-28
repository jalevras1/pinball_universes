# Batch 017 — first real machine sprite integration

The source artwork is the blue pop bumper from Pinball Universes Library Batch 014. A compact, optimized 80x80 transparent, indexed PNG is installed at assets/gameplay/mechanical/pop_bumper_blue_idle.png for mobile performance. It visually replaces the standard bumper art on **Astral Orrery** only; no collider positions, radii, bounce impulse, points, or gameplay physics have been changed. Existing universe artwork remains unchanged on all other tables.

Flutter tests verify that the actual PNG is bundled and reports the correct 80x80 dimensions. The original full-resolution sprite and animation remain saved in the persistent Library for later higher-resolution or hit-state integration. The current hit flash uses the game’s existing ring effect. Actual Android phone visual approval remains pending.
