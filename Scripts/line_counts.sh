#!/usr/bin/env bash
set -euo pipefail

# Run from anywhere inside the repo.
REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

tracked_files="$(git ls-files | wc -l | tr -d ' ')"
tracked_loc="$(
  git ls-files -z \
    | while IFS= read -r -d '' file; do
        if [ -f "$file" ]; then
          wc -l "$file"
        fi
      done \
    | awk '{sum += $1} END {print sum + 0}'
)"

echo "repo: $REPO_ROOT"
echo "tracked_files: $tracked_files"
echo "tracked_loc: $tracked_loc"
echo

echo "unstaged_diff:"
git diff --shortstat || true

echo "staged_diff:"
git diff --cached --shortstat || true

echo "last_commit_diff:"
git show --shortstat --oneline -n 1 HEAD | tail -n 1
