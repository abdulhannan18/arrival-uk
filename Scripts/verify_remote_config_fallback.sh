#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_CONFIG_PATH="${ROOT}/arrival uk/Data/DefaultConfig.json"
REMOTE_URL="${ARRIVAL_REMOTE_CONFIG_URL:-https://api.arrivaluk.app/config.json}"

echo "== Remote Config Fallback Verification =="
echo "Default config: ${DEFAULT_CONFIG_PATH}"
echo "Remote config URL: ${REMOTE_URL}"

if [[ ! -f "${DEFAULT_CONFIG_PATH}" ]]; then
  echo "[error] Missing local fallback config: ${DEFAULT_CONFIG_PATH}"
  exit 1
fi

python3 - "${DEFAULT_CONFIG_PATH}" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))

if "phase_3_config" not in data or "phase_4_wallet" not in data:
    raise SystemExit("[error] DefaultConfig.json must contain phase_3_config and phase_4_wallet.")

p3 = data["phase_3_config"]
p4 = data["phase_4_wallet"]

required_p3 = ("swipe_threshold", "spring_damping", "hero_card_limit")
required_p4 = ("required_docs", "biometric_enforced")

for key in required_p3:
    if key not in p3:
        raise SystemExit(f"[error] phase_3_config missing key: {key}")

for key in required_p4:
    if key not in p4:
        raise SystemExit(f"[error] phase_4_wallet missing key: {key}")

if not isinstance(p4["required_docs"], list) or len(p4["required_docs"]) == 0:
    raise SystemExit("[error] phase_4_wallet.required_docs must be a non-empty array.")

print("[pass] Local fallback config contract is valid.")
PY

status_code="$(
  curl \
    --location \
    --silent \
    --show-error \
    --output /dev/null \
    --write-out "%{http_code}" \
    --max-time 15 \
    --retry 1 \
    --retry-delay 1 \
    "${REMOTE_URL}" || true
)"

if [[ "${status_code}" =~ ^2[0-9][0-9]$ ]]; then
  echo "[pass] Remote config endpoint reachable (HTTP ${status_code})."
else
  echo "[warn] Remote config endpoint unreachable or non-2xx (HTTP ${status_code})."
  echo "[pass] Local fallback is valid, so startup still has a safe config path."
fi
