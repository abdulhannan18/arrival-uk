#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
OUT="$ROOT/docs/CODEBASE_DUMP.md"
mkdir -p "$(dirname "$OUT")"

lang_for() {
  case "$1" in
    *.swift) echo "swift" ;;
    *.ts) echo "ts" ;;
    *.tsx) echo "tsx" ;;
    *.js) echo "js" ;;
    *.jsx) echo "jsx" ;;
    *.json) echo "json" ;;
    *.md) echo "md" ;;
    *.sh) echo "bash" ;;
    *.plist) echo "xml" ;;
    *.pbxproj) echo "text" ;;
    *.xcworkspacedata) echo "xml" ;;
    *) echo "text" ;;
  esac
}

{
  echo "# Codebase Dump"
  echo
  echo "- repo: \`$ROOT\`"
  echo "- commit: \`$(git -C "$ROOT" rev-parse --short HEAD)\`"
  echo "- generated_at: \`$(date -u +"%Y-%m-%dT%H:%M:%SZ")\`"
  echo
} > "$OUT"

while IFS= read -r file; do
  full_path="$ROOT/$file"

  # Never read the dump file while regenerating it.
  if [ "$full_path" = "$OUT" ]; then
    continue
  fi

  # Skip deleted/missing tracked files gracefully.
  if [ ! -f "$full_path" ]; then
    continue
  fi

  # Skip binary files if any get tracked later.
  if ! grep -Iq . "$full_path"; then
    continue
  fi

  ext_lang="$(lang_for "$file")"
  {
    echo "## $file"
    echo
    echo "\`\`\`$ext_lang"
    cat "$full_path"
    echo
    echo "\`\`\`"
    echo
  } >> "$OUT"
done < <(git -C "$ROOT" ls-files)

echo "Generated: $OUT"
