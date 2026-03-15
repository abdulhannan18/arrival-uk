# Arrival UK - Technical Note for Claude Code

Last updated: 2026-02-10
Owner intent: production-grade iOS app now, Android-ready architecture next, zero progress loss.

## 1) Repository and source of truth
- Repo root: `/Users/abdulhannan/Desktop/arrival uk`
- Xcode project: `/Users/abdulhannan/Desktop/arrival uk/arrival uk.xcodeproj`
- iOS app code: `/Users/abdulhannan/Desktop/arrival uk/arrival uk`
- Backend code (Firebase): `/Users/abdulhannan/Desktop/arrival uk/backend`
- Architecture decisions: `/Users/abdulhannan/Desktop/arrival uk/ARCHITECTURE_DECISIONS.md`
- Handoff context: `/Users/abdulhannan/Desktop/arrival uk/DEVELOPER_HANDOFF.md`
- Current code map: `/Users/abdulhannan/Desktop/arrival uk/CODEBASE_MAP.md`
- Full text dump: `/Users/abdulhannan/Desktop/arrival uk/CODEBASE_DUMP.md`

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
  - `/Users/abdulhannan/Desktop/arrival uk/arrival uk/Data/content.json`
  - `/Users/abdulhannan/Desktop/arrival uk/arrival uk/Data/categories.json`
- Core state and content loading:
  - `/Users/abdulhannan/Desktop/arrival uk/arrival uk/ContentData.swift`
  - `/Users/abdulhannan/Desktop/arrival uk/arrival uk/ContentView.swift`
- Security and auth foundations:
  - `/Users/abdulhannan/Desktop/arrival uk/arrival uk/Security/ExternalURLPolicy.swift`
  - `/Users/abdulhannan/Desktop/arrival uk/arrival uk/Security/KeychainManager.swift`
  - `/Users/abdulhannan/Desktop/arrival uk/arrival uk/Auth/AuthStateValidator.swift`
- Networking and monetization:
  - `/Users/abdulhannan/Desktop/arrival uk/arrival uk/Networking/SecureHTTPClient.swift`
  - `/Users/abdulhannan/Desktop/arrival uk/arrival uk/AdSystem.swift`
- Backend security rules and functions:
  - `/Users/abdulhannan/Desktop/arrival uk/backend/firestore.rules`
  - `/Users/abdulhannan/Desktop/arrival uk/backend/storage.rules`
  - `/Users/abdulhannan/Desktop/arrival uk/backend/functions/src`

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
1. Read repo recursively from `/Users/abdulhannan/Desktop/arrival uk`.
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
  - `bash /Users/abdulhannan/Desktop/arrival uk/Scripts/line_counts.sh`
- Content validation:
  - `swift /Users/abdulhannan/Desktop/arrival uk/Scripts/validate_content.swift`
- iOS build:
  - `xcodebuild -project "/Users/abdulhannan/Desktop/arrival uk/arrival uk.xcodeproj" -scheme "arrival uk" -destination "platform=iOS Simulator,name=iPhone 15" CODE_SIGNING_ALLOWED=NO build`
- Strict smoke:
  - `bash /Users/abdulhannan/Desktop/arrival uk/Scripts/strict_smoke.sh`
- Backend lint/build:
  - `cd "/Users/abdulhannan/Desktop/arrival uk/backend/functions" && npm run lint && npm run build`

## 8) Immediate priorities
- Preserve and stabilize current feature set.
- Fix only verified defects/regressions.
- Keep Home and Category detail UX consistent.
- Keep security posture strict (URL policy, authz, secure storage).
- Do not introduce placeholder-only features into production paths.

## 9) Expected deliverables from Claude Code
- `REPORT_AUDIT.md`
- `REPORT_BACKLOG.csv`
- `REPORT_EXEC_SUMMARY.md`
- Optional after fixes:
  - `REPORT_FINAL_CHANGES.md`
  - `REPORT_TEST_RESULTS.md`

## 10) Success criteria
- No build break on iPhone 15 simulator.
- No data loss or progress reset.
- No new authz/privacy regressions.
- Cleaner, more maintainable code with functional equivalence preserved.
