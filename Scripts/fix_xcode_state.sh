#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="arrival uk"
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_ROOT="$HOME/Library/Developer/Xcode/DerivedData"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-/tmp/arrivaluk-derived}"
CLONED_SOURCE_PACKAGES_DIR_PATH="${CLONED_SOURCE_PACKAGES_DIR_PATH:-${HOME}/Library/Caches/arrivaluk-source-packages}"

printf "== Reset Xcode build state for %s ==\n" "$PROJECT_NAME"
printf "Project: %s\n" "$PROJECT_ROOT"

# 1) Stop running build jobs.
pkill -f "xcodebuild.*${PROJECT_NAME}" 2>/dev/null || true
pkill -f "swift-build" 2>/dev/null || true

# 2) Remove project-specific derived data.
find "$DERIVED_ROOT" -maxdepth 1 -type d -name "arrival_uk-*" -print -exec rm -rf {} +
rm -rf "${DERIVED_DATA_PATH}" || true

# 3) Reset simulator app installation.
xcrun simctl shutdown all || true
xcrun simctl erase "iPhone 15" || true

# 4) Resolve packages and rebuild once.
cd "$PROJECT_ROOT"
xcrun --version >/dev/null 2>&1 || true

python3 - "$CLONED_SOURCE_PACKAGES_DIR_PATH" <<'PY'
import os
import subprocess
import sys

cloned = sys.argv[1]
cmd = [
    "xcodebuild",
    "-resolvePackageDependencies",
    "-project", "arrival uk.xcodeproj",
    "-scheme", "arrival uk",
    "-clonedSourcePackagesDirPath", cloned,
]

try:
    subprocess.run(cmd, check=True, timeout=300)
except subprocess.TimeoutExpired:
    print("[warn] xcodebuild -resolvePackageDependencies timed out after 300s; continuing with build.")
except subprocess.CalledProcessError as exc:
    print(f"[warn] xcodebuild -resolvePackageDependencies failed (exit {exc.returncode}); continuing with build.")
PY
xcodebuild -project "arrival uk.xcodeproj" -scheme "arrival uk" -destination "platform=iOS Simulator,name=iPhone 15" -clonedSourcePackagesDirPath "${CLONED_SOURCE_PACKAGES_DIR_PATH}" clean build

printf "\nReset complete. You can now open Xcode and run normally.\n"
