#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

SWIFT_TEST_BINARY="$TMP_DIR/ios_unit_smoke_tests"

swiftc \
  -parse-as-library \
  "$ROOT_DIR/arrival uk/Security/ExternalURLPolicy.swift" \
  "$ROOT_DIR/Scripts/ios_unit_smoke_tests.swift" \
  -o "$SWIFT_TEST_BINARY"

"$SWIFT_TEST_BINARY"
