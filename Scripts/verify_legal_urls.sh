#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${ARRIVAL_LEGAL_BASE_URL:-https://arrivaluk.app}"
BASE_URL="${BASE_URL%/}"

if [[ ! "$BASE_URL" =~ ^https:// ]]; then
  echo "[error] ARRIVAL_LEGAL_BASE_URL must use https:// (received: ${BASE_URL})"
  exit 1
fi

PATHS=(
  "privacy"
  "terms"
  "support"
  "delete-data"
)

FAILURES=0

echo "== Legal URL Verification =="
echo "Base URL: ${BASE_URL}"

for path in "${PATHS[@]}"; do
  url="${BASE_URL}/${path}"
  status_code="$(
    curl \
      --location \
      --silent \
      --show-error \
      --output /dev/null \
      --write-out "%{http_code}" \
      --max-time 20 \
      --retry 2 \
      --retry-delay 1 \
      --retry-connrefused \
      "$url" || true
  )"

  if [[ "$status_code" =~ ^[23][0-9][0-9]$ ]]; then
    echo "[pass] ${url} -> HTTP ${status_code}"
  else
    echo "[fail] ${url} -> HTTP ${status_code}"
    FAILURES=$((FAILURES + 1))
  fi
done

if [[ "$FAILURES" -gt 0 ]]; then
  echo "Legal URL verification failed with ${FAILURES} endpoint(s)."
  exit 1
fi

echo "Legal URL verification passed."
