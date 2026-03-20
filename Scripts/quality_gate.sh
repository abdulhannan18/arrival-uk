#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

python3 - <<'PYTHON'
from pathlib import Path
import re
import sys

root = Path('.')
scan_dirs = [root / 'arrival uk', root / 'backend/functions/src']
scan_exts = {'.swift', '.ts', '.js', '.json'}
obvious_secret_patterns = [
    re.compile(r'AIza[0-9A-Za-z\-_]{35}'),
    re.compile(r'sk_(live|test)_[0-9A-Za-z]+', re.IGNORECASE),
    re.compile(r'gh[pousr]_[0-9A-Za-z]{20,}', re.IGNORECASE),
    re.compile(r'AKIA[0-9A-Z]{16}'),
]
legacy_force_unwraps = {
    'arrival uk/Core/CollaborationSyncEngine.swift:229',
    'arrival uk/Core/RegionalRuntime.swift:254',
    'arrival uk/Core/RegionalRuntime.swift:255',
    'arrival uk/Core/RegionalRuntime.swift:272',
    'arrival uk/Core/RegionalRuntime.swift:273',
    'arrival uk/Core/RegionalRuntime.swift:296',
    'arrival uk/Core/RegionalRuntime.swift:297',
    'arrival uk/Core/RegionalRuntime.swift:320',
    'arrival uk/Core/RegionalRuntime.swift:321',
    'arrival uk/Core/RegionalRuntime.swift:343',
    'arrival uk/Core/RegionalRuntime.swift:344',
    'arrival uk/Core/RegionalRuntime.swift:364',
    'arrival uk/Core/RegionalRuntime.swift:366',
    'arrival uk/Core/RegionalRuntime.swift:368',
    'arrival uk/Core/RegionalRuntime.swift:370',
    'arrival uk/Core/RegionalRuntime.swift:372',
    'arrival uk/Core/RegionalRuntime.swift:379',
    'arrival uk/Core/RegionalRuntime.swift:381',
    'arrival uk/Core/RegionalRuntime.swift:383',
    'arrival uk/Core/RegionalRuntime.swift:385',
    'arrival uk/Core/RegionalRuntime.swift:387',
    'arrival uk/Views/HorizonPriorityEngineViews.swift:1329',
}
legacy_swift_loc_budget = {
    'arrival uk/ContentView.swift': 2312,
    'arrival uk/Core/TaskSyncStore.swift': 1225,
    'arrival uk/Views/HomeHeaderViews.swift': 1220,
    'arrival uk/Views/HorizonPriorityEngineViews.swift': 1793,
    'arrival uk/Views/TaskDetailSheetView.swift': 1221,
}
force_unwrap_pattern = re.compile(r'[A-Za-z0-9_\)\]]!')
results = {
    'todo': [],
    'http': [],
    'secrets': [],
    'oversized': [],
    'force_unwrap': [],
}

for base in scan_dirs:
    if not base.exists():
        continue
    for path in sorted(base.rglob('*')):
        if not path.is_file() or path.suffix not in scan_exts:
            continue
        rel = path.as_posix()
        http_scan = not (path.suffix in {'.ts', '.js'} and path.name.endswith('.test.ts'))
        try:
            text = path.read_text()
        except UnicodeDecodeError:
            continue
        for lineno, line in enumerate(text.splitlines(), start=1):
            if re.search(r'\b(TODO|FIXME|HACK|XXX)\b', line):
                results['todo'].append(f'{rel}:{lineno}:{line}')
            if http_scan and 'http://' in line:
                results['http'].append(f'{rel}:{lineno}:{line}')
            if any(pattern.search(line) for pattern in obvious_secret_patterns):
                results['secrets'].append(f'{rel}:{lineno}:{line}')
            if path.suffix == '.swift' and force_unwrap_pattern.search(line):
                location = f'{rel}:{lineno}'
                if location not in legacy_force_unwraps:
                    results['force_unwrap'].append(f'{location}:{line}')
        if path.suffix == '.swift':
            line_count = text.count('\n') + (0 if text.endswith('\n') or not text else 1)
            limit = legacy_swift_loc_budget.get(rel, 1200)
            if line_count > limit:
                results['oversized'].append(f'{line_count} {rel} (limit {limit})')

failures = 0

def report(kind: str, header: str, passed: str):
    global failures
    entries = results[kind]
    if entries:
        print(f'[FAIL] {header}')
        for entry in entries:
            print(entry)
        failures += 1
    else:
        print(f'[PASS] {passed}')

report('todo', 'Found TODO/FIXME/HACK markers in shipping source', 'No TODO/FIXME/HACK markers in shipping source')
report('http', 'Found insecure http:// references in source', 'No insecure http:// references in source')
report('secrets', 'Found obvious hardcoded secret values in source', 'No obvious hardcoded secret values in source')
report('oversized', 'Found Swift files exceeding their LOC budget', 'No Swift files exceed their LOC budget')
report('force_unwrap', 'Found non-baselined force-unwrap usage', 'No non-baselined force-unwrap patterns detected')

if failures:
    print(f'\nQuality gate failed with {failures} issue(s).')
    sys.exit(1)

print('\nQuality gate passed.')
PYTHON

if [[ -n "${IOS_XCRESULT_PATH:-}" ]]; then
  bash Scripts/check_ios_coverage.sh "$IOS_XCRESULT_PATH"
fi
