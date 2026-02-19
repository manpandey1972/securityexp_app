#!/bin/sh
set -e

echo "🚀 Flutter setup for Xcode Cloud..."

REPO_ROOT="${CI_WORKSPACE:-${CI_PRIMARY_REPOSITORY_PATH:-$(pwd)}}"
echo "📁 Repository root: $REPO_ROOT"

FLUTTER_ROOT="$HOME/flutter"
rm -rf "$FLUTTER_ROOT"
git clone https://github.com/flutter/flutter.git --depth 1 -b 3.38.1 "$FLUTTER_ROOT"
export PATH="$FLUTTER_ROOT/bin:$PATH"

flutter --version
flutter doctor -v
flutter config --no-analytics

cd "$REPO_ROOT"

flutter clean
flutter pub get
flutter precache --ios

cd ios
pod deintegrate || true
pod cache clean --all

# Let Flutter handle CocoaPods correctly
flutter build ios --no-codesign

# Verify audioplayers_darwin pod
if [ -d "$REPO_ROOT/ios/Pods/audioplayers_darwin" ]; then
  echo "✅ audioplayers_darwin pod installed"
else
  echo "❌ audioplayers_darwin pod NOT installed!"
  exit 1
fi

echo "✅ Flutter setup complete!"
