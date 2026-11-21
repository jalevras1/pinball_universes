#!/usr/bin/env bash
# Pinball Universes: non-destructive Flutter web environment diagnosis and repair.
# Run inside the existing pinball_universes Codespace, on its development branch.
set -Eeuo pipefail

REPO_DIR="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$REPO_DIR" || "$(basename "$REPO_DIR")" != pinball_universes ]]; then
  echo 'STOP: This script runs only in the pinball_universes repository.'
  exit 2
fi
cd "$REPO_DIR"
REMOTE="$(git remote get-url origin 2>/dev/null || true)"
BRANCH="$(git branch --show-current)"
if [[ "$REMOTE" != *jalevras1/pinball_universes* || "$BRANCH" != chatgpt-pinball-development ]]; then
  echo "STOP: Unexpected repository or branch: $REMOTE ($BRANCH)."
  exit 3
fi

LOG_DIR="$REPO_DIR/.pinball_diagnostics/$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$LOG_DIR"
echo "Pinball Flutter diagnosis started. Logs: $LOG_DIR"
echo 'Game files and the original Flutter SDK will not be deleted.'

unset DART_VM_OPTIONS
export CI=true
ORIGINAL_FLUTTER="$HOME/flutter_sdk_pinball/bin/flutter"
if [[ ! -x "$ORIGINAL_FLUTTER" ]]; then
  ORIGINAL_FLUTTER="$(command -v flutter || true)"
fi
if [[ -z "$ORIGINAL_FLUTTER" || ! -x "$ORIGINAL_FLUTTER" ]]; then
  echo 'STOP: No executable Flutter SDK found. Nothing changed.'
  exit 4
fi

run_step() {
  local name="$1"
  shift
  echo "Running $name..."
  local status=0
  "$@" > "$LOG_DIR/$name.log" 2>&1 || status=$?
  echo "$status" > "$LOG_DIR/$name.exit"
  if (( status == 0 )); then
    echo "PASS $name"
  else
    echo "FAIL $name (exit $status); last log lines:"
    tail -n 12 "$LOG_DIR/$name.log" || true
  fi
  return "$status"
}

# Keep a small, non-secret record of machine resources and package state.
{
  date -u
  printf 'repo=%s\nbranch=%s\nflutter=%s\n' "$REPO_DIR" "$BRANCH" "$ORIGINAL_FLUTTER"
  git status --short
  free -h
  df -h "$REPO_DIR" "$HOME"
  ulimit -a
  if [[ -r /sys/fs/cgroup/memory.events ]]; then
    printf 'cgroup memory events:\n'
    cat /sys/fs/cgroup/memory.events
  fi
} > "$LOG_DIR/environment.log" 2>&1
run_step original_flutter_version timeout 180s "$ORIGINAL_FLUTTER" --version || true

probe_sdk() {
  local sdk="$1"
  local label="$2"
  local probe_dir
  probe_dir="$(mktemp -d "${TMPDIR:-/tmp}/pinball-flutter-${label}.XXXXXXXX")"
  if ! run_step "${label}_create" timeout 240s "$sdk" create --project-name pinball_probe --platforms=web --no-pub "$probe_dir"; then
    return 1
  fi
  (
    cd "$probe_dir"
    run_step "${label}_pub_get" timeout 300s "$sdk" pub get || return 1
    run_step "${label}_web_build" timeout 600s "$sdk" build web --release --no-wasm-dry-run --verbose
  )
}

ACTIVE_FLUTTER="$ORIGINAL_FLUTTER"
if probe_sdk "$ORIGINAL_FLUTTER" original; then
  echo 'PASS: The original Flutter SDK builds a clean web application.'
else
  echo 'The existing SDK failed the clean-app test. Repairing its web artifact cache...'
  # Flutter's documented --force option refreshes stale cache stamps/artifacts.
  run_step original_web_precache timeout 600s "$ORIGINAL_FLUTTER" precache --web --force || true
  if probe_sdk "$ORIGINAL_FLUTTER" refreshed; then
    echo 'PASS: Web artifacts refreshed; original Flutter SDK now builds.'
  else
    # A clean SDK next to the original avoids overwriting or corrupting it.
    RECOVERY_SDK="$HOME/flutter_sdk_pinball_recovery_3_50_1"
    AVAILABLE_KIB="$(df -Pk "$HOME" | awk 'NR==2 {print $4}')"
    if (( AVAILABLE_KIB < 6 * 1024 * 1024 )); then
      echo 'SKIP alternate SDK: less than 6 GiB of free disk space.'
    elif [[ -e "$RECOVERY_SDK" && ! -x "$RECOVERY_SDK/bin/flutter" ]]; then
      echo "SKIP alternate SDK: $RECOVERY_SDK exists but is incomplete; preserving it."
    else
      if [[ -x "$RECOVERY_SDK/bin/flutter" ]]; then
        echo 'Reusing the existing separate recovery SDK.'
        CLONE_OK=0
      else
        echo 'Installing an untouched Flutter 3.50.1 beside the current SDK (without replacing it)...'
        CLONE_OK=0
        run_step recovery_sdk_clone timeout 1200s git clone --depth 1 --single-branch --branch 3.50.1 https://github.com/flutter/flutter.git "$RECOVERY_SDK" || CLONE_OK=$?
      fi
      if (( CLONE_OK == 0 )) && [[ -x "$RECOVERY_SDK/bin/flutter" ]]; then
        run_step recovery_web_precache timeout 900s "$RECOVERY_SDK/bin/flutter" precache --web || true
        if probe_sdk "$RECOVERY_SDK/bin/flutter" recovery; then
          ACTIVE_FLUTTER="$RECOVERY_SDK/bin/flutter"
          echo 'PASS: Separate clean Flutter 3.50.1 SDK builds a web app.'
        fi
      fi
    fi
  fi
fi

if [[ "$ACTIVE_FLUTTER" == "$ORIGINAL_FLUTTER" ]]; then
  # A fresh proof under the original SDK is needed before declaring success.
  if [[ "$(cat "$LOG_DIR/original_web_build.exit" 2>/dev/null || echo 1)" != 0 &&
        "$(cat "$LOG_DIR/refreshed_web_build.exit" 2>/dev/null || echo 1)" != 0 ]]; then
    echo 'NOT REPAIRED: Even a minimal Flutter web app fails under the original SDK.'
    echo "Inspect the detailed *_web_build.log files at $LOG_DIR"
    echo 'No game files or SDK installations were removed.'
    exit 10
  fi
fi

if [[ ! -f "$REPO_DIR/pubspec.yaml" ]]; then
  echo 'SDK READY, PROJECT BLOCKED: pubspec.yaml is missing from this checkout.'
  echo 'The game files were preserved. Initialize the Flutter project separately.'
  exit 11
fi

echo 'Checking the actual Pinball Universes web build...'
if ! run_step pinball_pub_get timeout 300s "$ACTIVE_FLUTTER" pub get; then
  echo 'SDK READY, PROJECT DEPENDENCIES FAILED. Read pinball_pub_get.log.'
  exit 12
fi
if ! run_step pinball_web_build timeout 900s "$ACTIVE_FLUTTER" build web --release --no-wasm-dry-run --verbose; then
  echo 'SDK READY, PROJECT BUILD FAILED. Read pinball_web_build.log.'
  exit 13
fi

if [[ "$ACTIVE_FLUTTER" != "$ORIGINAL_FLUTTER" ]]; then
  printf 'export PATH="%s/bin:$PATH"\n' "$(dirname "$(dirname "$ACTIVE_FLUTTER")")" > "$LOG_DIR/activate_recovery_sdk.sh"
  echo "To use the working SDK in this terminal: source '$LOG_DIR/activate_recovery_sdk.sh'"
fi
echo 'PINBALL_FLUTTER_WEB_BUILD_OK'
echo "Verified build: $REPO_DIR/build/web"
echo "Diagnostic logs: $LOG_DIR"
