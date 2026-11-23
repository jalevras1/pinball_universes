#!/usr/bin/env bash
# One-action protected candidate install into an EXISTING authenticated Codespace.
# The currently active playable checkout is NEVER switched or overwritten.
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo 'Usage: run18_apply_test.sh /absolute/path/to/existing/pinball_universes'
  exit 2
fi

package_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
live_repo="$1"
expected_base='0dc54ea1e01c9a6deb83d0c110f74fe7542425ac'
feature='feature/pinball-straight-shooter-20261123'
candidate_worktree="$(dirname "$live_repo")/pinball-run18-candidate"

cd "$live_repo"
[[ -d .git || -f .git ]] || { echo 'Not a git checkout'; exit 3; }
actual_remote="$(git remote get-url origin)"
[[ "$actual_remote" == *'jalevras1/pinball_universes'* ]] || {
  echo 'Wrong game repository; refusing to proceed'; exit 3;
}
if [[ -n "$(git status --porcelain)" ]]; then
  echo 'Existing local changes detected; preserving them and stopping'; exit 4
fi
git fetch origin chatgpt-pinball-development
actual_base="$(git rev-parse origin/chatgpt-pinball-development)"
if [[ "$actual_base" != "$expected_base" ]]; then
  echo "Development HEAD changed ($actual_base); reconcile candidate first"; exit 5
fi
if [[ -e "$candidate_worktree" ]] || git show-ref --verify --quiet "refs/heads/$feature"; then
  echo 'Candidate worktree or branch already exists; refusing overwrite'; exit 6
fi

git worktree add -b "$feature" "$candidate_worktree" "$expected_base"
cd "$candidate_worktree"
for item in \
  lib/game/pinball_game.dart lib/game/plunger_model.dart \
  lib/game/shooter_lane.dart lib/game/swept_rail.dart lib/main.dart \
  test/gameplay_mechanics_test.dart test/plunger_model_test.dart \
  test/shooter_lane_test.dart test/swept_rail_test.dart; do
  install -D "$package_root/$item" "$candidate_worktree/$item"
done

# Failure leaves this separate candidate available for troubleshooting. Neither
# development nor main is moved, committed, merged, pushed or published here.
dart format --output=none --set-exit-if-changed lib test
flutter pub get
flutter analyze
flutter test
flutter build web --release
echo 'Automated code gates complete. Manual browser and Android QA still required.'
echo "Candidate checkout: $candidate_worktree"
