#!/usr/bin/env bash
set -euo pipefail

# Crashlytics symbol upload for SwiftPM.
# - Skips Debug builds to keep developer builds fast.
# - Skips when GoogleService-Info.plist isn't present (repo can build without Firebase).
# - Uses the Firebase iOS SDK Crashlytics run script from SourcePackages.

STAMP_FILE="${SCRIPT_OUTPUT_FILE_0:-}"

touch_stamp() {
  if [[ -z "${STAMP_FILE}" ]]; then
    return 0
  fi

  mkdir -p "$(dirname "${STAMP_FILE}")"
  touch "${STAMP_FILE}"
}

if [[ "${CONFIGURATION:-}" == "Debug" ]]; then
  touch_stamp
  exit 0
fi

APP_BUNDLE="${BUILT_PRODUCTS_DIR:-}/${CONTENTS_FOLDER_PATH:-}"
GOOGLE_PLIST="${APP_BUNDLE}/GoogleService-Info.plist"

if [[ ! -f "${GOOGLE_PLIST}" ]]; then
  echo "[Crashlytics] GoogleService-Info.plist missing; skipping dSYM upload."
  touch_stamp
  exit 0
fi

CRASHLYTICS_RUN="${BUILD_DIR%/Build/*}/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run"

if [[ ! -x "${CRASHLYTICS_RUN}" ]]; then
  echo "[Crashlytics] Crashlytics run script not found (expected ${CRASHLYTICS_RUN}); skipping."
  touch_stamp
  exit 0
fi

"${CRASHLYTICS_RUN}"
touch_stamp
