#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-/tmp/arrivaluk-derived}"
CLONED_SOURCE_PACKAGES_DIR_PATH="${CLONED_SOURCE_PACKAGES_DIR_PATH:-${HOME}/Library/Caches/arrivaluk-source-packages}"
SCHEME="${SCHEME:-arrival uk}"
PROJECT_FILE="${PROJECT_FILE:-arrival uk.xcodeproj}"
SIMULATOR_NAME="${SIMULATOR_NAME:-}"
BUNDLE_ID="${BUNDLE_ID:-com.arrivaluk.arrival-uk}"
SMOKE_ITERATIONS="${SMOKE_ITERATIONS:-8}"

if [[ -z "${SIMULATOR_NAME}" ]]; then
  for candidate in "iPhone 15" "iPhone 16" "iPhone 14" "iPhone 13"; do
    if xcrun simctl list devices available | grep -Fq "${candidate} ("; then
      SIMULATOR_NAME="${candidate}"
      break
    fi
  done
fi

if [[ -z "${SIMULATOR_NAME}" ]]; then
  SIMULATOR_NAME="$(
    xcrun simctl list devices available \
      | sed -n 's/^[[:space:]]*\\([^()]*iPhone[^()]*\\) ([0-9A-F-]*) (.*available.*)$/\\1/p' \
      | head -n 1 \
      | xargs
  )"
fi

if [[ -z "${SIMULATOR_NAME}" ]]; then
  echo "ERROR: No available iPhone simulator found." >&2
  exit 1
fi

echo "== Arrival UK Strict Smoke =="
echo "Project root: ${PROJECT_ROOT}"
echo "Derived data: ${DERIVED_DATA_PATH}"
echo "Cloned packages: ${CLONED_SOURCE_PACKAGES_DIR_PATH}"
echo "Simulator: ${SIMULATOR_NAME}"

cd "${PROJECT_ROOT}"

mkdir -p "${CLONED_SOURCE_PACKAGES_DIR_PATH}"

echo
echo "1) Validating bundled content JSON"
swift Scripts/validate_content.swift

echo
echo "2) Building iOS simulator target"
xcodebuild \
  -project "${PROJECT_FILE}" \
  -scheme "${SCHEME}" \
  -destination "platform=iOS Simulator,name=${SIMULATOR_NAME}" \
  -clonedSourcePackagesDirPath "${CLONED_SOURCE_PACKAGES_DIR_PATH}" \
  -derivedDataPath "${DERIVED_DATA_PATH}" \
  CODE_SIGNING_ALLOWED=NO \
  build > /tmp/arrivaluk-smoke-build.log

APP_PATH="${DERIVED_DATA_PATH}/Build/Products/Debug-iphonesimulator/${SCHEME}.app"
if [[ ! -d "${APP_PATH}" ]]; then
  echo "ERROR: Built app not found at ${APP_PATH}" >&2
  exit 1
fi

echo
echo "3) Installing and repeatedly launching simulator app (${SMOKE_ITERATIONS}x)"
xcrun simctl boot "${SIMULATOR_NAME}" >/dev/null 2>&1 || true
xcrun simctl install "${SIMULATOR_NAME}" "${APP_PATH}"

for i in $(seq 1 "${SMOKE_ITERATIONS}"); do
  xcrun simctl terminate "${SIMULATOR_NAME}" "${BUNDLE_ID}" >/dev/null 2>&1 || true
  launch_output="$(xcrun simctl launch "${SIMULATOR_NAME}" "${BUNDLE_ID}" 2>/tmp/arrivaluk-launch.err)" || {
    echo "ERROR: Launch command failed at iteration ${i}" >&2
    cat /tmp/arrivaluk-launch.err >&2 || true
    exit 1
  }
  sleep 1
  if [[ ! "${launch_output}" =~ :[[:space:]]*[0-9]+$ ]]; then
    echo "ERROR: Launch check failed at iteration ${i}" >&2
    echo "${launch_output}" >&2
    exit 1
  fi
  echo "  - launch ${i}/${SMOKE_ITERATIONS} OK"
done

echo
echo "4) Building generic iOS target"
xcodebuild \
  -project "${PROJECT_FILE}" \
  -scheme "${SCHEME}" \
  -destination "generic/platform=iOS" \
  -clonedSourcePackagesDirPath "${CLONED_SOURCE_PACKAGES_DIR_PATH}" \
  -derivedDataPath "${DERIVED_DATA_PATH}" \
  CODE_SIGNING_ALLOWED=NO \
  build > /tmp/arrivaluk-device-build.log

echo
echo "Strict smoke run passed."
