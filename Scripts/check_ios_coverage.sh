#!/usr/bin/env bash
set -euo pipefail

XCRESULT_PATH="${1:-${IOS_XCRESULT_PATH:-}}"
if [[ -z "${XCRESULT_PATH}" ]]; then
  echo "Usage: $0 <xcresult-path>" >&2
  exit 2
fi

if [[ ! -d "${XCRESULT_PATH}" ]]; then
  echo "Coverage xcresult not found at ${XCRESULT_PATH}" >&2
  exit 1
fi

REPORT_JSON="$(mktemp /tmp/arrivaluk-xccov-XXXXXX.json)"
trap 'rm -f "$REPORT_JSON"' EXIT

xcrun xccov view --report --json "$XCRESULT_PATH" > "$REPORT_JSON"

python3 - "$REPORT_JSON" <<'PYTHON'
import json
import sys
from pathlib import Path

report = json.loads(Path(sys.argv[1]).read_text())
required = {
    'TaskSyncStore.swift': 0.80,
    'CollaborationSyncEngine.swift': 0.80,
    'MarketplacePaymentCoordinator.swift': 0.80,
}

files = {}

def visit(node):
    if isinstance(node, dict):
        path = node.get('path')
        line_coverage = node.get('lineCoverage')
        if isinstance(path, str) and isinstance(line_coverage, (int, float)):
            files[Path(path).name] = float(line_coverage)
        for value in node.values():
            visit(value)
    elif isinstance(node, list):
        for value in node:
            visit(value)

visit(report)

missing = []
for name, threshold in required.items():
    coverage = files.get(name)
    if coverage is None:
        missing.append(f'{name}: missing from xccov report')
    elif coverage + 1e-9 < threshold:
        missing.append(f'{name}: {coverage:.1%} < {threshold:.0%}')
    else:
        print(f'[PASS] {name} line coverage {coverage:.1%} >= {threshold:.0%}')

if missing:
    print('[FAIL] iOS coverage gate failed')
    for entry in missing:
        print(entry)
    sys.exit(1)

print('[PASS] iOS coverage gate passed')
PYTHON
