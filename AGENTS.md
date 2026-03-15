# Arrival UK Workspace Guide

Use this folder as the only source of truth:
`/Users/abdulhannan/Documents/Projects/Arrival UK`

## Main paths

- `arrival uk.xcodeproj/` Xcode project to open
- `arrival uk/` iOS app source
- `arrival ukTests/` iOS tests
- `ArrivalWidgetExtension/` widget/live activity extension
- `backend/` Firebase backend scaffold and hosting assets
- `docs/` all project documentation
- `docs/reports/` audits and status reports
- `docs/backend/` backend planning and architecture notes
- `Scripts/` validation and maintenance scripts
- `AppConfig/` shared config assets

## Important notes

- Do not use any old `Desktop/arrival uk` or `Documents/New project` paths.
- There is only one real project location now: this folder.
- `docs/generated/CODEBASE_DUMP.md` is generated on demand and is intentionally not tracked.
- `backend/functions/lib/` is currently kept because the backend workflow still points `main` to built JS there.

## Good starting files

- `README.md`
- `docs/CLAUDE_PROJECT_BRIEF.md`
- `docs/CLAUDE_SESSION_PROMPT.md`
- `docs/CODEBASE_MAP.md`
- `docs/DEVELOPER_HANDOFF.md`

## Useful commands

- `git status --short --branch`
- `bash Scripts/line_counts.sh`
- `swift Scripts/validate_content.swift`
- `bash Scripts/strict_smoke.sh`
- `xcodebuild -project "arrival uk.xcodeproj" -scheme "arrival uk" -destination "platform=iOS Simulator,name=iPhone 15" CODE_SIGNING_ALLOWED=NO build`
- `cd backend/functions && npm run lint && npm run build`
- `bash Scripts/build_codebase_dump.sh`

## Finder guidance

- If asked to open the app in Xcode, use `arrival uk.xcodeproj`.
- If asked where docs live, use `docs/`, especially `docs/reports/` and `docs/backend/`.
- Avoid creating duplicate project folders or alternate aliases for this repo.
