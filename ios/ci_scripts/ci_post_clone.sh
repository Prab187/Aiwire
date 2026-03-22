#!/bin/sh

# Xcode Cloud ci_post_clone.sh
# Installs Flutter and generates ephemeral plugin files before the Xcode build.

set -e

echo "=== Installing Flutter ==="

# Clone Flutter SDK
git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$HOME/flutter"
export PATH="$HOME/flutter/bin:$PATH"

echo "Flutter version:"
flutter --version

echo "=== Running flutter pub get ==="
cd "$CI_PRIMARY_REPOSITORY_PATH"
flutter pub get

echo "=== Generating iOS build files ==="
flutter build ios --config-only --no-codesign

echo "=== ci_post_clone.sh complete ==="
