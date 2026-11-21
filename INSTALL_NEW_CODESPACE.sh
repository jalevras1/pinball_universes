#!/usr/bin/env bash
set -euo pipefail

# Installs into the independent pinball_universes repository only.
PINBALL_SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PINBALL_REPO_DIR="$(git -C "$PINBALL_SOURCE_DIR" rev-parse --show-toplevel 2>/dev/null || true)"

if [ -z "$PINBALL_REPO_DIR" ] || [ "$(basename "$PINBALL_REPO_DIR")" != "pinball_universes" ]; then
  echo "STOP: Run inside the pinball_universes Codespace only. Dragon files are safe."
  exit 2
fi
if [ ! -f "$PINBALL_SOURCE_DIR/lib/main.dart" ] ||
   [ ! -f "$PINBALL_SOURCE_DIR/assets/gameplay/steel_ball.png" ]; then
  echo "STOP: The pinball package is incomplete."
  exit 3
fi
if [ -f "$PINBALL_REPO_DIR/.pinball_installed" ]; then
  echo "STOP: Pinball already installed; no game files replaced."
  exit 4
fi

if ! command -v flutter >/dev/null 2>&1; then
  PINBALL_FLUTTER_SDK="$HOME/flutter_sdk_pinball"
  if [ ! -x "$PINBALL_FLUTTER_SDK/bin/flutter" ]; then
    echo "Installing official Flutter stable SDK. This can take several minutes..."
    if [ -e "$PINBALL_FLUTTER_SDK" ]; then
      echo "STOP: Flutter SDK folder exists but seems incomplete."
      exit 5
    fi
    git clone --depth 1 --branch stable https://github.com/flutter/flutter.git "$PINBALL_FLUTTER_SDK"
  fi
  export PATH="$PINBALL_FLUTTER_SDK/bin:$PATH"
  if ! grep -Fqx 'export PATH="$HOME/flutter_sdk_pinball/bin:$PATH"' "$HOME/.bashrc" 2>/dev/null; then
    printf '%s\n' 'export PATH="$HOME/flutter_sdk_pinball/bin:$PATH"' >> "$HOME/.bashrc"
  fi
fi

echo "Checking Flutter..."
flutter --version

cd "$PINBALL_REPO_DIR"
if [ ! -f pubspec.yaml ]; then
  flutter create --project-name premium_pinball --platforms=web,android .
fi
if ! grep -Eq '^name: premium_pinball[[:space:]]*$' pubspec.yaml; then
  echo "STOP: A different Flutter project already exists in this repo."
  exit 6
fi

echo "Installing dependencies and assets..."
flutter pub add flame flame_forge2d shared_preferences
cp -R "$PINBALL_SOURCE_DIR/lib/." "$PINBALL_REPO_DIR/lib/"
cp -R "$PINBALL_SOURCE_DIR/test/." "$PINBALL_REPO_DIR/test/"
mkdir -p "$PINBALL_REPO_DIR/assets"
cp -R "$PINBALL_SOURCE_DIR/assets/." "$PINBALL_REPO_DIR/assets/"

if ! grep -q '^    - assets/universe_covers/' pubspec.yaml; then
  if ! grep -q '^  uses-material-design: true$' pubspec.yaml; then
    echo "STOP: Could not find the Flutter asset configuration."
    exit 7
  fi
  sed -i '/^  uses-material-design: true$/a\  assets:\n    - assets/universe_covers/\n    - assets/gameplay/' pubspec.yaml
fi

echo "Formatting, analyzing, testing, and building the web prototype..."
dart format lib test
flutter analyze
flutter test
flutter build web

printf 'PINBALL_UNIVERSES_RUN03_WEB_BUILD_OK\n' > .pinball_installed
git add .gitignore .metadata analysis_options.yaml pubspec.yaml pubspec.lock lib test assets web android .pinball_installed
if ! git diff --cached --quiet; then
  git commit -m "Install Pinball Universes prototype with nine board configurations"
  if git push origin HEAD:chatgpt-pinball-development; then
    echo "PINBALL_FILES_SAVED_TO_GITHUB_OK"
  else
    echo "WARNING: Build passed; GitHub push did not complete. Local commit is saved."
  fi
fi

echo "PINBALL_UNIVERSES_RUN03_WEB_BUILD_OK"
echo "Web preview starting on port 8766. Tap Open in Browser in the Ports panel."
python3 -m http.server 8766 --directory build/web
