# Arrival UK - Technical Note for Claude Code

Last updated: 2026-02-10
Owner intent: production-grade iOS app now, Android-ready architecture next, zero progress loss.

## 1) Repository and source of truth
- Finder location: `/Users/abdulhannan/Documents/Projects/Arrival UK`
- Repo root: `.`
- Xcode project: `arrival uk.xcodeproj`
- iOS app code: `arrival uk/`
- Backend code (Firebase): `backend/`
- Architecture decisions: `docs/ARCHITECTURE_DECISIONS.md`
- Handoff context: `docs/DEVELOPER_HANDOFF.md`
- Current code map: `docs/CODEBASE_MAP.md`
- Full text dump: `docs/CODEBASE_DUMP.md`

## 2) Product ambition and constraints
- Primary goal: robust checklist app for students moving to the UK.
- Engineering goal: preserve all working behavior while hardening security, reliability, and maintainability.
- Future goal: keep data schema, business rules, and design tokens portable for Android implementation.
- Non-negotiable:
  - Do not remove existing progress.
  - Do not perform broad rewrites without explicit approval.
  - Prefer incremental, testable edits in small batches.

## 3) Current architecture baseline
- Data-driven content:
  - `arrival uk/Data/content.json`
  - `arrival uk/Data/categories.json`
- Core state and content loading:
  - `arrival uk/ContentData.swift`
  - `arrival uk/ContentView.swift`
- Security and auth foundations:
  - `arrival uk/Security/ExternalURLPolicy.swift`
  - `arrival uk/Security/KeychainManager.swift`
  - `arrival uk/Auth/AuthStateValidator.swift`
- Networking and monetization:
  - `arrival uk/Networking/SecureHTTPClient.swift`
  - `arrival uk/AdSystem.swift`
- Backend security rules and functions:
  - `backend/firestore.rules`
  - `backend/storage.rules`
  - `backend/functions/src`

## 4) What changed recently (important context)
- Firestore and Storage rules were tightened for ownership/privacy.
- Callable email and SMS functions were hardened with auth checks and rate limits.
- Notification scheduling was made more idempotent/scalable.
- App config force unwrap URL risks were removed.
- `Scripts/line_counts.sh` and `Scripts/build_codebase_dump.sh` were fixed to tolerate deleted tracked files.

## 5) Known collaboration risks
- Two agents editing the same file at the same time can cause merge churn.
- The workspace may be dirty. Do not reset/revert unrelated user work.
- Track counts in `CODEBASE_MAP.md` may lag behind local uncommitted changes.

## 6) Required workflow for Claude Code
1. Read the repo recursively from the repo root.
2. Produce findings before edits:
   - `Critical`, `High`, `Medium`, `Low`
   - include exact `file:line`, root cause, impact, fix.
3. Apply fixes in small batches only (Critical first).
4. Validate after each batch:
   - content validation
   - iOS build
   - backend lint/build where relevant
5. Commit each approved batch with clear messages.

## 7) Validation commands
- Line counts:
  - `bash Scripts/line_counts.sh`
- Content validation:
  - `swift Scripts/validate_content.swift`
- iOS build:
  - `xcodebuild -project "arrival uk.xcodeproj" -scheme "arrival uk" -destination "platform=iOS Simulator,name=iPhone 15" CODE_SIGNING_ALLOWED=NO build`
- Strict smoke:
  - `bash Scripts/strict_smoke.sh`
- Backend lint/build:
  - `cd backend/functions && npm run lint && npm run build`

## 8) Immediate priorities
- Preserve and stabilize current feature set.
- Fix only verified defects/regressions.
- Keep Home and Category detail UX consistent.
- Keep security posture strict (URL policy, authz, secure storage).
- Do not introduce placeholder-only features into production paths.

## 9) Expected deliverables from Claude Code
- `docs/REPORT_AUDIT.md`
- `docs/REPORT_BACKLOG.csv`
- `docs/REPORT_EXEC_SUMMARY.md`
- Optional after fixes:
  - `REPORT_FINAL_CHANGES.md`
  - `REPORT_TEST_RESULTS.md`

## 10) Success criteria
- No build break on iPhone 15 simulator.
- No data loss or progress reset.
- No new authz/privacy regressions.
- Cleaner, more maintainable code with functional equivalence preserved.
