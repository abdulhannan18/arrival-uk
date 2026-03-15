#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

failures=0

pass() { echo "[PASS] $1"; }
fail() { echo "[FAIL] $1"; failures=$((failures + 1)); }

# 1) No TODO/FIXME/HACK in shipping source.
if rg -n "\\b(TODO|FIXME|HACK|XXX)\\b" "arrival uk" backend/functions/src --glob '*.{swift,ts,js}' >/tmp/arrivaluk-quality-todos.txt; then
  fail "Found TODO/FIXME/HACK markers in shipping source"
  cat /tmp/arrivaluk-quality-todos.txt
else
  pass "No TODO/FIXME/HACK markers in shipping source"
fi

# 2) No insecure HTTP in production source (tests are excluded).
if rg -n "http://" "arrival uk" backend/functions/src --glob '*.{swift,ts,js,json}' --glob '!*.test.ts' >/tmp/arrivaluk-quality-http.txt; then
  fail "Found insecure http:// references in source"
  cat /tmp/arrivaluk-quality-http.txt
else
  pass "No insecure http:// references in source"
fi

# 3) No obvious hardcoded secrets.
if rg -n "(api[_-]?key|secret|password|token)\s*[:=]\s*['\"][^'\"]+['\"]" "arrival uk" backend/functions/src --glob '*.{swift,ts,js}' >/tmp/arrivaluk-quality-secrets.txt; then
  fail "Possible hardcoded secret/token patterns detected"
  cat /tmp/arrivaluk-quality-secrets.txt
else
  pass "No obvious hardcoded secret/token patterns"
fi

# 4) Swift file size soft ceiling (maintainability).
oversized="$(find "arrival uk" -name '*.swift' -type f -print0 | xargs -0 wc -l | awk '$2 ~ /\\.swift$/ && $1 > 1200 {print}')"
if [[ -n "${oversized}" ]]; then
  fail "Found Swift files exceeding 1200 LOC"
  echo "$oversized"
else
  pass "No Swift files exceed 1200 LOC"
fi

# 5) Force unwrap detector (high-risk crashes).
if rg -n "[A-Za-z0-9_\)\]]!" "arrival uk" --glob '*.swift' >/tmp/arrivaluk-quality-forceunwrap.txt; then
  fail "Potential force-unwrap usage detected"
  cat /tmp/arrivaluk-quality-forceunwrap.txt
else
  pass "No force-unwrap patterns detected"
fi

if [[ "$failures" -gt 0 ]]; then
  echo "\nQuality gate failed with ${failures} issue(s)."
  exit 1
fi

echo "\nQuality gate passed."
