#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_FILE="${ROOT}/arrival uk.xcodeproj/project.pbxproj"
CRASHLYTICS_SCRIPT="${ROOT}/Scripts/crashlytics_run.sh"

echo "== Crash Symbolication Verification =="

if [[ ! -f "${PROJECT_FILE}" ]]; then
  echo "[error] project.pbxproj not found: ${PROJECT_FILE}"
  exit 1
fi

if [[ ! -x "${CRASHLYTICS_SCRIPT}" ]]; then
  echo "[error] Crashlytics run script is missing or not executable: ${CRASHLYTICS_SCRIPT}"
  exit 1
fi

if ! rg -q 'name = "Crashlytics Run";' "${PROJECT_FILE}"; then
  echo "[error] Crashlytics Run build phase is missing."
  exit 1
fi

if ! rg -q '\$\(SRCROOT\)/Scripts/crashlytics_run\.sh' "${PROJECT_FILE}"; then
  echo "[error] Crashlytics build phase is not wired to Scripts/crashlytics_run.sh."
  exit 1
fi

if ! rg -q '\$\(DWARF_DSYM_FOLDER_PATH\)/\$\(DWARF_DSYM_FILE_NAME\)' "${PROJECT_FILE}"; then
  echo "[error] dSYM folder input path is missing from Crashlytics build phase."
  exit 1
fi

if ! rg -q '\$\(DWARF_DSYM_FOLDER_PATH\)/\$\(DWARF_DSYM_FILE_NAME\)/Contents/Resources/DWARF/\$\(TARGET_NAME\)' "${PROJECT_FILE}"; then
  echo "[error] dSYM binary input path is missing from Crashlytics build phase."
  exit 1
fi

if ! rg -q '\$\(BUILT_PRODUCTS_DIR\)/\$\(INFOPLIST_PATH\)' "${PROJECT_FILE}"; then
  echo "[error] Info.plist input path is missing from Crashlytics build phase."
  exit 1
fi

echo "Crash symbolication setup looks valid."
