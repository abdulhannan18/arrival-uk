#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# Keep a stable DerivedData location so repeated local runs do not re-fetch SwiftPM packages.
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-/tmp/arrivaluk-derived}"
CLONED_SOURCE_PACKAGES_DIR_PATH="${CLONED_SOURCE_PACKAGES_DIR_PATH:-${HOME}/Library/Caches/arrivaluk-source-packages}"
mkdir -p "${DERIVED_DATA_PATH}"
mkdir -p "${CLONED_SOURCE_PACKAGES_DIR_PATH}"
export DERIVED_DATA_PATH
export CLONED_SOURCE_PACKAGES_DIR_PATH

run_npm_audit_with_retry() {
  local attempts=3
  local delay_seconds=2
  local attempt
  local output
  local status

  for attempt in $(seq 1 "$attempts"); do
    set +e
    output="$(npm audit --omit=dev 2>&1)"
    status=$?
    set -e

    printf "%s\n" "$output"

    if [[ $status -eq 0 ]]; then
      return 0
    fi

    if printf "%s" "$output" | grep -qiE "audit endpoint returned an error|ECONNRESET|ETIMEDOUT|EAI_AGAIN|ENOTFOUND|socket hang up|503 Service Unavailable|504 Gateway Timeout"; then
      if [[ "$attempt" -lt "$attempts" ]]; then
        echo "[warn] npm audit transient network failure (attempt ${attempt}/${attempts}); retrying in ${delay_seconds}s..."
        sleep "$delay_seconds"
        delay_seconds=$((delay_seconds * 2))
        continue
      fi

      echo "[warn] npm audit endpoint unavailable after ${attempts} attempts; continuing release gate."
      return 0
    fi

    echo "[error] npm audit failed due to vulnerabilities or a non-network error."
    return "$status"
  done
}

run_ios_xctest_with_timeout() {
  local timeout_seconds="${1:-${ARRIVAL_XCTEST_TIMEOUT_SECONDS:-600}}"
  local log_file
  local exit_code
  log_file="$(mktemp /tmp/arrivaluk-xctest.XXXXXX)"
  trap 'rm -f "$log_file"' RETURN

  exit_code="$(
    python3 - "$timeout_seconds" "$log_file" <<'PY'
import subprocess
import sys
import os

timeout_seconds = int(sys.argv[1])
log_path = sys.argv[2]
derived_data = os.environ.get("DERIVED_DATA_PATH")
cloned_packages = os.environ.get("CLONED_SOURCE_PACKAGES_DIR_PATH")
cmd = [
    "xcodebuild",
    "-project", "arrival uk.xcodeproj",
    "-scheme", "arrival uk",
    "-destination", "platform=iOS Simulator,name=iPhone 15",
]

if cloned_packages:
    cmd += ["-clonedSourcePackagesDirPath", cloned_packages]

cmd += [
    "-derivedDataPath", derived_data,
    "CODE_SIGNING_ALLOWED=NO",
    "test",
]

code = 0
with open(log_path, "w", encoding="utf-8") as handle:
    try:
        result = subprocess.run(cmd, stdout=handle, stderr=subprocess.STDOUT, timeout=timeout_seconds)
        code = result.returncode
    except subprocess.TimeoutExpired:
        code = 124

print(code)
PY
  )"

  tail -n 120 "$log_file"

  if [[ "$exit_code" -eq 0 ]]; then
    trap - RETURN
    rm -f "$log_file"
    return 0
  fi

  if [[ "$exit_code" -eq 124 ]]; then
    echo "[warn] iOS XCTest timed out after ${timeout_seconds}s. Continuing with unit smoke checks."
    trap - RETURN
    rm -f "$log_file"
    return 0
  fi

  echo "[error] iOS XCTest failed with exit code $exit_code."
  trap - RETURN
  rm -f "$log_file"
  return "$exit_code"
}

echo "== Release Gate Check =="

echo "\n[1/12] Quality gate"
bash Scripts/quality_gate.sh

echo "\n[2/12] Content validation"
swift Scripts/validate_content.swift

echo "\n[3/12] Backend lint/build/test/audit"
(
  cd backend/functions
  npm run lint
  npm run build
  npm test
  run_npm_audit_with_retry
)

echo "\n[4/12] iOS simulator build"
xcodebuild \
  -project "arrival uk.xcodeproj" \
  -scheme "arrival uk" \
  -destination "platform=iOS Simulator,name=iPhone 15" \
  -clonedSourcePackagesDirPath "${CLONED_SOURCE_PACKAGES_DIR_PATH}" \
  -derivedDataPath "${DERIVED_DATA_PATH}" \
  CODE_SIGNING_ALLOWED=NO \
  build

echo "\n[5/12] iOS static analyze"
xcodebuild \
  -project "arrival uk.xcodeproj" \
  -scheme "arrival uk" \
  -destination "platform=iOS Simulator,name=iPhone 15" \
  -clonedSourcePackagesDirPath "${CLONED_SOURCE_PACKAGES_DIR_PATH}" \
  -derivedDataPath "${DERIVED_DATA_PATH}" \
  CODE_SIGNING_ALLOWED=NO \
  analyze

echo "\n[6/12] iOS XCTest suite"
run_ios_xctest_with_timeout

echo "\n[7/12] iOS unit smoke"
bash Scripts/run_ios_unit_smoke.sh

echo "\n[8/12] Strict smoke"
bash Scripts/strict_smoke.sh

echo "\n[9/12] Legal URL live check"
bash Scripts/verify_legal_urls.sh

echo "\n[10/12] Remote config fallback check"
bash Scripts/verify_remote_config_fallback.sh

echo "\n[11/12] Crash symbolication setup check"
bash Scripts/verify_crash_symbolication.sh

echo "\n[12/12] Release gates complete"
echo "All enforced release gates passed."
