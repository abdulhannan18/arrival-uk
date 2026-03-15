# Codebase Dump

- repo: `/Users/abdulhannan/Desktop/arrival uk`
- commit: `8072046`
- generated_at: `2026-02-10T18:20:02Z`

## .gitignore

```text
.DS_Store
._*

# Xcode local state and build output
DerivedData/
xcuserdata/
*.xcuserstate
*.xccheckout
*.moved-aside
build/
*.xcresult

# SwiftPM local artifacts
.build/
.swiftpm/

# Dependency directories
node_modules/
Pods/
backend/functions/node_modules/

# Generated backend transpilation output
backend/functions/lib/

# Local archives/backups
backups/

# Temporary export/debug artifacts
CHANGED_FILES_FULL_DUMP.txt
FULL_CODE_EXPORT/

```

## APP_LAUNCH_READINESS.md

```md
# Arrival UK - Launch Readiness Checklist (Living)

Last Updated: 2026-02-09  
Owner: Product + Engineering

This is the operational version of your checklist with priority and current status.

## P0 (Blockers Before App Store Submission)

- [ ] `Privacy Policy URL` live and added to App Store Connect.
- [ ] `Terms of Service URL` live and linked in app.
- [ ] `App Privacy` answers in App Store Connect match actual SDK behavior (Google Sign-In / ads / analytics).
- [ ] `Sign in with Apple` present whenever third-party auth is present.
- [ ] `ATT` flow implemented if tracking-enabled SDK behavior is used.
- [ ] `Crash reporting` integrated and validated in release-like build.
- [ ] `No secrets in app binary` (API keys/tokens not hardcoded).
- [ ] `ATS enforced` (no arbitrary HTTP loads).
- [ ] `Accessibility minimums` validated (VoiceOver, Dynamic Type, contrast).
- [ ] `Launch stability` proven by repeated simulator/device cold starts.

## P1 (Strongly Recommended Before External Beta)

- [ ] `Structured logging` (debug vs release behavior).
- [ ] `Unified error handling` with user-safe messages.
- [ ] `Data export/delete` flow for privacy rights.
- [ ] `Support entrypoint` in app (Report Problem / Support email).
- [ ] `In-app legal links` (Privacy, Terms, Ads disclosure).
- [ ] `Release configuration hardening` (strip symbols, assertions, optimization).
- [ ] `Performance baseline` measured (launch time, memory, dropped frames).
- [ ] `Regression checklist` run on every candidate build.

## P2 (Scale Readiness)

- [ ] `Feature flags` for risky/new features.
- [ ] `Config layer` for env and runtime controls.
- [ ] `Dependency injection` expansion for testability.
- [ ] `Repository abstraction` for future backend sync.
- [ ] `Schema versioning/migrations` for persisted data.
- [ ] `CI pipeline` with build + tests + analyze.
- [ ] `Deep links` and update enforcement strategy.

## Current Codebase Status (Verified)

### Done

- [x] External link policy with URL allowlist + normalization.
- [x] Keychain wrapper exists for sensitive storage.
- [x] Auth-state normalization for profile snapshot consistency.
- [x] Content validation script and strict smoke script exist.
- [x] Repeated simulator launch checks already scripted.

### Partially Done

- [~] ATS hardening present; final verification must include Info.plist/App Store privacy consistency review.
- [~] Auth flows present; full token lifecycle handling depends on backend/session rollout.

### Missing / Pending

- [ ] Crash reporting provider integration (Crashlytics/Sentry).
- [ ] App-level structured logger for release-safe telemetry.
- [ ] Unified AppError/ErrorHandler wiring across all feature flows.
- [ ] ATT + consent UX finalized relative to monetization mode.
- [ ] Legal URLs and support workflows finalized in product settings UI.
- [ ] Automated CI gates (build + analyze + smoke + tests).

## Release Gate (Do Not Submit Unless All True)

- [ ] No open P0 items.
- [ ] Last 3 candidate builds pass strict smoke without white-screen startup failure.
- [ ] Crash-free startup on iPhone SE class + iPhone 15 class tested manually.
- [ ] App Privacy, legal text, and in-app behavior are consistent.

## Execution Order (Recommended)

1. Finish legal/privacy artifacts and wire URLs in app.
2. Integrate crash reporting and structured error pipeline.
3. Finalize ATT/ads consent behavior.
4. Add CI automation for repeatable release checks.
5. Run full regression + performance pass on release candidate.

```

## ARCHITECTURE_DECISIONS.md

```md
# Arrival UK Architecture Decisions

Last updated: 2026-02-10
Status: active baseline

This file preserves the key architecture decisions made during implementation so they do not depend on chat history.

## ADR-001: Data-driven content is the source of truth
- Decision: Task/category content is driven by bundled JSON payloads, not hardcoded UI text.
- Why: Easier updates, cross-platform parity, and safer content validation.
- Implemented in: `arrival uk/ContentData.swift`, `arrival uk/Data/content.json`, `arrival uk/Data/categories.json`, `Scripts/validate_content.swift`.

## ADR-002: Safe startup pipeline with fallback and validation
- Decision: App primes quickly, then resolves bundled payloads with strict validation and controlled fallback behavior.
- Why: Prevent white screens and malformed content crashes.
- Implemented in: `arrival uk/ContentData.swift`.
- Guardrail: Fallback merge must not silently reintroduce removed tasks/categories in normal bundle paths.

## ADR-003: Single store for progress and content state
- Decision: Content/progress state is centralized in store logic instead of duplicated across views.
- Why: Consistency, easier debugging, predictable persistence.
- Implemented in: `arrival uk/ContentData.swift`, `arrival uk/ContentView.swift`.

## ADR-004: Security hardening on external links
- Decision: All external links are normalized and validated before open.
- Why: Prevent unsafe schemes/hosts and policy drift.
- Implemented in: `arrival uk/Security/ExternalURLPolicy.swift`, wired from `arrival uk/ContentView.swift` and validators.

## ADR-005: Secure sign-out and keychain-ready sensitive storage
- Decision: Provide keychain wrapper and secure sign-out path that clears sensitive/session state.
- Why: Production readiness and future auth token safety.
- Implemented in: `arrival uk/Security/KeychainManager.swift`, `arrival uk/StudentProfile.swift`.

## ADR-006: Design tokens + system modifiers
- Decision: Use centralized theme/spacing/motion/performance primitives.
- Why: Consistency, lower styling drift, easier platform parity.
- Implemented in: `arrival uk/DesignSystem.swift`.

## ADR-007: Search as first-class feature module
- Decision: Task search is implemented as a feature module, not inline screen-only logic.
- Why: Better separation, easier iteration.
- Implemented in: `arrival uk/Features/Search/TaskSearchSheet.swift`.

## ADR-008: Safety and reminders are modular features
- Decision: Emergency contacts and notifications live in isolated feature modules.
- Why: Maintainability and low-risk evolution.
- Implemented in: `arrival uk/Features/Safety/EmergencyContactsSheet.swift`, `arrival uk/Features/Notifications/NotificationManager.swift`, `arrival uk/Features/Notifications/PushNotificationManager.swift`.

## ADR-009: Networking abstraction prepared before backend scaling
- Decision: Add a secure HTTP client abstraction even before full backend rollout.
- Why: Consistent transport/security rules and future migration path.
- Implemented in: `arrival uk/Networking/SecureHTTPClient.swift`.

## ADR-010: Ad system is policy-driven
- Decision: Ad behavior is controlled via policy/coordinator abstractions and consent state.
- Why: Compliance control and safe monetization behavior.
- Implemented in: `arrival uk/AdSystem.swift`.

## ADR-011: Cross-platform readiness by schema and tokens
- Decision: iOS UI remains native, while keeping schemas and token semantics portable to Android.
- Why: Realistic cross-platform migration without forcing shared UI.
- Implemented by convention in: `arrival uk/Data/*.json`, `arrival uk/DesignSystem.swift`, model semantics in `arrival uk/Models.swift`.

## ADR-012: Release hardening scripts are part of repo workflow
- Decision: Keep validation/smoke scripts in-repo and run before release candidates.
- Why: Repeatable quality gates.
- Implemented in: `Scripts/validate_content.swift`, `Scripts/strict_smoke.sh`.

## Operational rule
- Any major architecture change should add a new ADR section in this file with:
  - decision
  - reason
  - file paths
  - migration impact

```

## CODEBASE_MAP.md

```md
# Codebase Map

- Repo root: /Users/abdulhannan/Desktop/arrival uk
- Commit: 8072046
- Tracked files: 58
- Tracked LOC: 16668
- Full dump file: CODEBASE_DUMP.md

## Top-Level
- .git
- Scripts
- arrival uk
- arrival uk.xcodeproj
- backend
- backend-docs
- backups

## Tracked Files
- .gitignore
- APP_LAUNCH_READINESS.md
- ARCHITECTURE_DECISIONS.md
- CODEBASE_MAP.md
- DEVELOPER_HANDOFF.md
- PROJECT_BASELINE.md
- PROJECT_PROGRESS_BASELINE.md
- Scripts/line_counts.sh
- Scripts/strict_smoke.sh
- Scripts/validate_content.swift
- arrival uk.xcodeproj/project.pbxproj
- arrival uk.xcodeproj/project.xcworkspace/contents.xcworkspacedata
- arrival uk.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
- arrival uk.xcodeproj/xcuserdata/abdulhannan.xcuserdatad/xcschemes/xcschememanagement.plist
- arrival uk/AdSystem.swift
- arrival uk/Assets.xcassets/AccentColor.colorset/Contents.json
- arrival uk/Assets.xcassets/AppIcon.appiconset/Contents.json
- arrival uk/Assets.xcassets/Contents.json
- arrival uk/Auth/AuthStateValidator.swift
- arrival uk/Auth/AuthenticationManager.swift
- arrival uk/ContentData.swift
- arrival uk/ContentView.swift
- arrival uk/Core/AppConfig.swift
- arrival uk/Core/CrashReporter.swift
- arrival uk/Data/categories.json
- arrival uk/Data/content.json
- arrival uk/DesignSystem.swift
- arrival uk/Features/Notifications/NotificationManager.swift
- arrival uk/Features/Notifications/PushNotificationManager.swift
- arrival uk/Features/Safety/EmergencyContactsSheet.swift
- arrival uk/Features/Search/TaskSearchSheet.swift
- arrival uk/Models.swift
- arrival uk/Networking/SecureHTTPClient.swift
- arrival uk/Security/ExternalURLPolicy.swift
- arrival uk/Security/KeychainManager.swift
- arrival uk/StudentProfile.swift
- arrival uk/arrival_ukApp.swift
- backend-docs/api-specification-v1.md
- backend-docs/chunk-1-gap-analysis.md
- backend-docs/chunk-2-gap-analysis.md
- backend-docs/firebase-architecture.md
- backend-docs/firebase-setup-complete.md
- backend-docs/firestore-data-model.md
- backend-docs/storage-architecture.md
- backend/README.md
- backend/firebase.json
- backend/firestore.indexes.json
- backend/firestore.rules
- backend/functions/package-lock.json
- backend/functions/package.json
- backend/functions/src/auth.ts
- backend/functions/src/email.ts
- backend/functions/src/index.ts
- backend/functions/src/notifications.ts
- backend/functions/src/sms.ts
- backend/functions/src/storage.ts
- backend/functions/tsconfig.json
- backend/storage.rules

```

## DEVELOPER_HANDOFF.md

```md
# Arrival UK - Developer Handoff Note

Last updated: 2026-02-09
Owner context: iOS SwiftUI app, Android considered in future via feature/design parity (not shared Swift UI code).

## 1. Current Product Snapshot
- App type: iOS SwiftUI checklist app for international students moving to the UK.
- Core UX: Home categories -> category detail -> task detail -> official guidance links.
- Runtime status: builds and launches successfully on simulator and iOS target.
- Content source of truth: bundled JSON in `/Users/abdulhannan/Desktop/arrival uk/arrival uk/Data/content.json` and `/Users/abdulhannan/Desktop/arrival uk/arrival uk/Data/categories.json`.
- Current bundled data: 5 categories in both files, with richer tasks in `content.json`.

## 2. Codebase Structure (What Lives Where)
- `/Users/abdulhannan/Desktop/arrival uk/arrival uk/arrival_ukApp.swift`
  - App entry point.
- `/Users/abdulhannan/Desktop/arrival uk/arrival uk/ContentView.swift`
  - Main feature shell and almost all UI composition.
  - Home screen, category cards, detail overlay, modal system, profile sheet wiring, task sheet wiring, help/privacy sheets.
- `/Users/abdulhannan/Desktop/arrival uk/arrival uk/ContentData.swift`
  - ContentStore, bundle loading, payload merge/sanitize/normalize, validation and fallback helpers.
  - Progress persistence and restoration.
- `/Users/abdulhannan/Desktop/arrival uk/arrival uk/Models.swift`
  - All task/category/content section models and sample data.
- `/Users/abdulhannan/Desktop/arrival uk/arrival uk/DesignSystem.swift`
  - Theme tokens, spacing, motion, haptics, performance profile, layer z-index, modifiers.
- `/Users/abdulhannan/Desktop/arrival uk/arrival uk/StudentProfile.swift`
  - Student profile store, Apple/Google auth state model, persistence.
- `/Users/abdulhannan/Desktop/arrival uk/arrival uk/AdSystem.swift`
  - Ad policy/consent/runtime abstraction and coordinator.
- `/Users/abdulhannan/Desktop/arrival uk/Scripts/validate_content.swift`
  - JSON integrity validator used before builds.

## 3. Design and Architecture Principles Already Applied
- Data-driven content first: UI renders from decoded JSON content structures.
- Fail-safe startup:
  - Prime quickly with sample data.
  - Load bundle data async and replace safely.
  - Persist/restore task completion and custom tasks.
- Layered modal architecture:
  - Base content, category overlay, modal overlay have fixed z-index roles from `DesignSystem.swift`.
- Performance intent:
  - Background decode for bundle + progress snapshot where possible.
  - Conservative rendering path available via performance profile.
- Accessibility intent:
  - Dynamic type, reduced motion checks, semantic labels in key flows.

## 4. Important Fixes Already Implemented

### 4.1 Content fallback merge no longer re-adds removed content
- File: `/Users/abdulhannan/Desktop/arrival uk/arrival uk/ContentData.swift`
- Key area: `mergePayload(...)` and caller flags in `resolveCategoriesFromBundle()`.
- Change:
  - Added `includeFallbackOnlyCategories` flag.
  - For normal bundle load paths, both flags are set false:
    - `includeFallbackOnlyTasks: false`
    - `includeFallbackOnlyCategories: false`
- Outcome:
  - Primary JSON stays authoritative.
  - Intentionally removed tasks/categories are not silently reintroduced by sample fallback merge.

### 4.2 Progress snapshot decode moved off main path for bundle load
- File: `/Users/abdulhannan/Desktop/arrival uk/arrival uk/ContentData.swift`
- Key area: `loadFromBundle()` and new `decodeProgressSnapshot(storageKey:)`.
- Change:
  - Bundle resolution and persisted snapshot decode occur in background queue.
  - Snapshot is cached and then applied on main actor.
- Outcome:
  - Lower risk of startup hitch/jank.

### 4.3 Profile save hardened for auth provider correctness
- File: `/Users/abdulhannan/Desktop/arrival uk/arrival uk/ContentView.swift`
- Key area: `saveProfile()` in `ProfileSetupSheet`.
- Change:
  - Persist Google identity only when `authProvider == .google`.
  - Removed behavior that could persist Google email while provider was `.none`.
- Outcome:
  - Prevents accidental provider drift and invalid auth state persistence.

## 5. Modal and Interaction Rules (Do Not Break)
- Backdrop must visually dim and block underlying interactions.
- Foreground modal content must be above backdrop layer and receive touches.
- Avoid introducing `absolute` overlay panels for action areas unless strictly required.
- Keep modal content in scrollable vertical flow to avoid clipping/overlap on small screens.

## 6. Startup and White-Screen Behavior
Intermittent white/blank view can happen if startup sequence is blocked or content fails to render in the visible state.
Current mitigation in code:
- Startup placeholder while bootstrapping.
- Prime data path before full load.
- Async bundle load and progress apply.

If blank screen appears in QA:
1. Validate content JSON using validator script.
2. Check simulator/device logs for JSON decode/validation events.
3. Delete app from simulator/device to clear persisted state and relaunch.
4. Rebuild clean with derived data path reset.

## 7. How to Safely Make Future Changes
- Change tokens first, not hardcoded values:
  - colors, spacing, motion, z-layers in `DesignSystem.swift`.
- Change content in JSON + models, not by hardcoded UI text.
- Keep `ContentData` merge behavior strict unless explicitly implementing migration behavior.
- When adding features, preserve these boundaries:
  - UI composition in `ContentView` and extracted views.
  - state/persistence in stores.
  - models in `Models.swift`.

## 8. Cross-Platform Readiness Guidance
Current code is native SwiftUI and not directly reusable on Android UI.
To stay Android-ready:
- Keep business logic and data schema platform-agnostic:
  - content JSON schema
  - task/category semantics
  - progress/auth rules
- Keep design tokens documented and mirrored in Android:
  - colors, spacing, typography scale, elevation/shadow intent, motion durations.
- Avoid iOS-only assumptions in data model semantics.

## 9. Build and Validation Commands
Run from project root `/Users/abdulhannan/Desktop/arrival uk`.

- Validate content:
  - `swift Scripts/validate_content.swift`
- Build for simulator:
  - `xcodebuild -project 'arrival uk.xcodeproj' -scheme 'arrival uk' -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/arrivaluk-derived CODE_SIGNING_ALLOWED=NO build`
- Build generic iOS device target:
  - `xcodebuild -project 'arrival uk.xcodeproj' -scheme 'arrival uk' -destination 'generic/platform=iOS' -derivedDataPath /tmp/arrivaluk-derived CODE_SIGNING_ALLOWED=NO build`
- Install + launch on simulator:
  - `xcrun simctl install 'iPhone 17' '/tmp/arrivaluk-derived/Build/Products/Debug-iphonesimulator/arrival uk.app'`
  - `xcrun simctl launch 'iPhone 17' com.arrivaluk.arrival-uk`

## 10. QA Checklist Before Any Merge
- Content validator passes with zero errors.
- App builds for simulator and generic iOS target.
- Home loads with categories visible.
- Category open works and task list appears.
- Task detail modal buttons are tappable.
- Source link opens expected URL.
- No text overlap in modals on small and large iPhone sizes.
- Profile save preserves correct auth provider state.
- No regressions in completion/progress persistence after relaunch.

## 11. Next Refactor Recommendation (Optional but High Value)
`ContentView.swift` is very large. For maintainability, extract to files without behavior change:
- `HomeScreenView.swift`
- `CategoryDetailOverlay.swift`
- `TaskDetailSheet.swift`
- `ProfileSetupSheet.swift`
- `HelpAndPrivacySheets.swift`

Keep this a mechanical extraction only (no logic changes) to reduce regression risk.

## 12. Non-Negotiable Precautions
- Do not silently re-enable fallback-only category/task merge in production path.
- Do not put heavy decode/parsing on main actor during startup.
- Do not persist auth identity for a provider that is not active.
- Do not mix design-token and hardcoded styling in the same component tree.
- Always validate JSON + build before handing to QA.

## 13. Security Foundation Audit Status (2026-02-09)

### Completed in code
- URL security policy implemented:
  - Added `/Users/abdulhannan/Desktop/arrival uk/arrival uk/Security/ExternalURLPolicy.swift`.
  - Only allows `https` globally.
  - Allows `http` only for trusted suffixes (`gov.uk`, `ac.uk`, `nhs.uk`, etc.).
  - Blocks localhost/local-network style hosts for external navigation.
- External URL handling hardened:
  - `ContentView` now routes all external open actions through `ExternalURLPolicy`.
  - Task detail source links, references, step actions, help/privacy links now use validated URLs.
- Content validation hardened:
  - `ContentData` validator now uses `ExternalURLPolicy.normalizedURL(...)`.
  - Official/university trust checks use the same policy layer to avoid policy drift.
- Auth-state integrity hardened:
  - Added `/Users/abdulhannan/Desktop/arrival uk/arrival uk/Auth/AuthStateValidator.swift`.
  - Persisted profile auth snapshot is normalized on load to repair invalid provider/id combinations.
- Secure sign-out path added:
  - Added `/Users/abdulhannan/Desktop/arrival uk/arrival uk/Security/KeychainManager.swift`.
  - Added `secureSignOut()` in `StudentProfileStore` and wired profile sign-out flow to call it.
  - Keychain keys are reserved for future auth token/refresh token storage and are cleared on sign-out.
- ATS hardening set explicitly in build settings:
  - `NSAllowsArbitraryLoads = NO` for Debug and Release via generated Info.plist keys.

### Validation completed
- Content validation:
  - `swift Scripts/validate_content.swift` -> 0 warnings, 0 errors.
- Build validation:
  - Simulator build succeeded.
  - Generic iOS build succeeded (via strict smoke script).
- Stability validation:
  - `Scripts/strict_smoke.sh` passed (8 repeated install+launch cycles).
- Static analysis:
  - `xcodebuild ... analyze` succeeded.

### Remaining high-priority items (not yet implemented)
- Replace placeholder privacy policy URL:
  - Current value in `AdSystem.swift` is `https://example.com/privacy`.
  - Must be replaced with live policy URL before production/TestFlight.
- Add explicit data export/delete user flow (GDPR/UK GDPR readiness).
- Add crash reporting (e.g., Crashlytics) and error telemetry pipeline.
- Add dependency vulnerability scanning to CI.
- Add automated UI test coverage for auth handoff and external link opening paths.

### Recommended next execution order
1. Replace privacy policy URL + add legal links screen polish.
2. Implement data export + account/data deletion.
3. Add crash reporting + lightweight analytics abstraction.
4. Add CI gate: content validation + build + smoke + analyzer on pull request.

```

## PROJECT_BASELINE.md

```md
# Arrival UK - Baseline (Code + Goals)

## 1) Project Location and Directory Issue

- Canonical project path: `/Users/abdulhannan/Desktop/arrival uk`
- Alias path used by tools: `/Users/abdulhannan/Documents/New project`
- Current state: working and resolved. `/Users/abdulhannan/Documents/New project` points to the same project directory.

## 2) Current Code Inventory

### Main app files
- `/Users/abdulhannan/Documents/New project/arrival uk/arrival_ukApp.swift`
- `/Users/abdulhannan/Documents/New project/arrival uk/ContentView.swift`
- `/Users/abdulhannan/Documents/New project/arrival uk/Data/content.json`

### Project config and assets
- `/Users/abdulhannan/Documents/New project/arrival uk.xcodeproj/project.pbxproj`
- `/Users/abdulhannan/Documents/New project/arrival uk/Assets.xcassets/Contents.json`

### What is implemented now
- SwiftUI single-screen checklist app with:
- Header, progress section, journey strip, category cards, and "Add Personal Task".
- Categories:
- Before Arrival
- Health & Admin
- Money & Banking
- Travel & Discounts
- Add-task sheet and task completion toggles.
- Task details sheet with timing/priority badges and optional source link button.
- Haptic feedback on completion (guarded for low power mode).
- Theme system with light/dark support.
- Content loading from bundled JSON (`content.json`) with fallback to sample data.
- Starter task dataset seeded in `content.json` (pre-arrival, admin, banking, travel).
- Ad policy engine wired to app events (warm-up, interaction threshold, cooldown, hourly/session caps).
- Ad & Privacy settings screen implemented (personalization toggle, tracking status, policy link).
- Consent state persisted locally and synchronized with runtime ad request mode.
- Category safety filters implemented in-app (blocked sensitive categories are rejected before request).

## 3) Performance Work Already Applied

- Replaced standard stacks with lazy rendering (`LazyVStack`) for better scaling.
- Deferred optional visual effects until after first frame to reduce launch work.
- Simplified progress fill rendering to avoid unnecessary layout cost.
- Reused haptic generator instead of creating one on every tap.
- Added aggregate stats structs to avoid repeated full-array recalculations.
- Added startup telemetry markers (debug logging) for init, content load, and first-frame effects.
- Added conservative rendering mode for low-memory or Low Power Mode devices.
- Added in-memory payload cache and memory-mapped JSON read path for bundled content.

## 4) Build and Runtime Status

- Command-line simulator build currently succeeds:
- `xcodebuild -project "/Users/abdulhannan/Documents/New project/arrival uk.xcodeproj" -scheme "arrival uk" -destination "generic/platform=iOS Simulator" -derivedDataPath /tmp/arrivaluk-derived CODE_SIGNING_ALLOWED=NO build`
- `content.json` is confirmed copied into app bundle at build output.
- Earlier `UUID` vs `String` ID mismatch was resolved in `AddTaskSheet`.

## 5) Product Goals Agreed So Far

- Core purpose: guide international students with UK setup steps from pre-arrival to early settle-in.
- Quality bar: no compromise on speed, smoothness, functionality, and clean premium UI.
- Platform: iOS first (17+), Android later with portable content architecture.
- UX tone: professional, serious, friendly, uncluttered, high trust.
- Monetization for initial launch: ads only, no affiliate links.
- Ad policy: delayed after warm-up, non-disruptive, no gambling/sensitive categories.
- Data quality: official references required for critical tasks.

## 6) Open Decisions

- Final app name and final icon system.
- Final typography and color token lock.
- Exact ad format and placement timing rules.
- Full category/task dataset and sequencing.
- Reminder cadence and iCloud sync timing.

## 7) What I Need From You to Build the Real Version

### Content inputs
- Full task list per category (title + short description).
- For each task: best timing window (for example, "2-4 weeks before arrival").
- Official source link for each task (gov/NHS/university/bank/transport).
- Priority level per task: must-do, should-do, optional.

### Product decisions
- Final app name.
- Final icon direction choice (playful-premium midpoint).
- Confirm first release ad policy:
- first ad delay (minutes),
- max frequency,
- allowed categories only.

### UX decisions
- Final color direction (2 to 3 brand colors).
- Typography choice.
- Reminder behavior (off by default or soft opt-in).

## 8) Next Build Steps (After Your Inputs)

1. Replace seeded starter tasks with your final verified dataset from official sources.
2. Add startup telemetry and app-launch tuning for older iPhones.
3. Add Google Mobile Ads package in Xcode so the conditional `GoogleMobileAds` client is activated in builds.
4. Lock visual system and icon set.
5. Prepare App Store release checklist.

```

## PROJECT_PROGRESS_BASELINE.md

```md
# Project Progress Baseline

Generated: 2026-02-10

- Swift LOC: 9301
- JSON LOC: 1392
- Total (Swift+JSON): 10693

## Top Files by Lines

- `arrival uk/ContentView.swift`: 3668
- `arrival uk/Models.swift`: 1372
- `arrival uk/ContentData.swift`: 1249
- `arrival uk/DesignSystem.swift`: 843
- `arrival uk/Data/content.json`: 670
- `arrival uk/Data/categories.json`: 670
- `arrival uk/AdSystem.swift`: 556
- `arrival uk/StudentProfile.swift`: 308
- `arrival uk/Features/Search/TaskSearchSheet.swift`: 178
- `arrival uk/Auth/AuthenticationManager.swift`: 162
- `arrival uk/Features/Safety/EmergencyContactsSheet.swift`: 156
- `arrival uk/Features/Notifications/PushNotificationManager.swift`: 146
- `arrival uk/Features/Notifications/NotificationManager.swift`: 126
- `arrival uk/Core/CrashReporter.swift`: 105
- `arrival uk/Security/KeychainManager.swift`: 103
- `arrival uk/Networking/SecureHTTPClient.swift`: 102
- `arrival uk/Core/AppConfig.swift`: 90
- `arrival uk/Security/ExternalURLPolicy.swift`: 70
- `arrival uk/Auth/AuthStateValidator.swift`: 43
- `arrival uk/Assets.xcassets/AppIcon.appiconset/Contents.json`: 35
- `arrival uk/arrival_ukApp.swift`: 24
- `arrival uk/Assets.xcassets/AccentColor.colorset/Contents.json`: 11
- `arrival uk/Assets.xcassets/Contents.json`: 6

```

## Scripts/line_counts.sh

```bash
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

```

## Scripts/strict_smoke.sh

```bash
#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-/tmp/arrivaluk-derived}"
SCHEME="${SCHEME:-arrival uk}"
PROJECT_FILE="${PROJECT_FILE:-arrival uk.xcodeproj}"
SIMULATOR_NAME="${SIMULATOR_NAME:-}"
BUNDLE_ID="${BUNDLE_ID:-com.arrivaluk.arrival-uk}"
SMOKE_ITERATIONS="${SMOKE_ITERATIONS:-8}"

if [[ -z "${SIMULATOR_NAME}" ]]; then
  for candidate in "iPhone 15" "iPhone 16" "iPhone 14" "iPhone 13"; do
    if xcrun simctl list devices available | grep -Fq "${candidate} ("; then
      SIMULATOR_NAME="${candidate}"
      break
    fi
  done
fi

if [[ -z "${SIMULATOR_NAME}" ]]; then
  SIMULATOR_NAME="$(
    xcrun simctl list devices available \
      | sed -n 's/^[[:space:]]*\\([^()]*iPhone[^()]*\\) ([0-9A-F-]*) (.*available.*)$/\\1/p' \
      | head -n 1 \
      | xargs
  )"
fi

if [[ -z "${SIMULATOR_NAME}" ]]; then
  echo "ERROR: No available iPhone simulator found." >&2
  exit 1
fi

echo "== Arrival UK Strict Smoke =="
echo "Project root: ${PROJECT_ROOT}"
echo "Derived data: ${DERIVED_DATA_PATH}"
echo "Simulator: ${SIMULATOR_NAME}"

cd "${PROJECT_ROOT}"

echo
echo "1) Validating bundled content JSON"
swift Scripts/validate_content.swift

echo
echo "2) Building iOS simulator target"
xcodebuild \
  -project "${PROJECT_FILE}" \
  -scheme "${SCHEME}" \
  -destination "platform=iOS Simulator,name=${SIMULATOR_NAME}" \
  -derivedDataPath "${DERIVED_DATA_PATH}" \
  CODE_SIGNING_ALLOWED=NO \
  build > /tmp/arrivaluk-smoke-build.log

APP_PATH="${DERIVED_DATA_PATH}/Build/Products/Debug-iphonesimulator/${SCHEME}.app"
if [[ ! -d "${APP_PATH}" ]]; then
  echo "ERROR: Built app not found at ${APP_PATH}" >&2
  exit 1
fi

echo
echo "3) Installing and repeatedly launching simulator app (${SMOKE_ITERATIONS}x)"
xcrun simctl boot "${SIMULATOR_NAME}" >/dev/null 2>&1 || true
xcrun simctl install "${SIMULATOR_NAME}" "${APP_PATH}"

for i in $(seq 1 "${SMOKE_ITERATIONS}"); do
  xcrun simctl terminate "${SIMULATOR_NAME}" "${BUNDLE_ID}" >/dev/null 2>&1 || true
  launch_output="$(xcrun simctl launch "${SIMULATOR_NAME}" "${BUNDLE_ID}" 2>/tmp/arrivaluk-launch.err)" || {
    echo "ERROR: Launch command failed at iteration ${i}" >&2
    cat /tmp/arrivaluk-launch.err >&2 || true
    exit 1
  }
  sleep 1
  if [[ ! "${launch_output}" =~ :[[:space:]]*[0-9]+$ ]]; then
    echo "ERROR: Launch check failed at iteration ${i}" >&2
    echo "${launch_output}" >&2
    exit 1
  fi
  echo "  - launch ${i}/${SMOKE_ITERATIONS} OK"
done

echo
echo "4) Building generic iOS target"
xcodebuild \
  -project "${PROJECT_FILE}" \
  -scheme "${SCHEME}" \
  -destination "generic/platform=iOS" \
  -derivedDataPath "${DERIVED_DATA_PATH}" \
  CODE_SIGNING_ALLOWED=NO \
  build > /tmp/arrivaluk-device-build.log

echo
echo "Strict smoke run passed."

```

## Scripts/validate_content.swift

```swift
#!/usr/bin/swift
import Foundation

enum Severity: String {
    case warning = "WARNING"
    case error = "ERROR"
}

struct Issue {
    let severity: Severity
    let path: String
    let message: String
}

enum Validator {
    private static let trustedOfficialDomainSuffixes: [String] = [
        "gov.uk",
        "ac.uk",
        "nhs.uk",
        "nationalrail.co.uk",
        "ukri.org.uk",
        "ukfinance.org.uk",
        "ukcisa.org.uk",
        "hsbc.co.uk",
        "lloydsbank.com",
        "aldi.co.uk",
        "tesco.com",
        "studentbeans.com",
        "totum.com"
    ]

    static func validate(data: Data, fileName: String) -> [Issue] {
        guard
            let object = try? JSONSerialization.jsonObject(with: data),
            let root = object as? [String: Any]
        else {
            return [Issue(severity: .error, path: fileName, message: "Invalid JSON document.")]
        }

        guard let categories = root["categories"] as? [[String: Any]] else {
            return [Issue(severity: .error, path: "\(fileName).categories", message: "Missing categories array.")]
        }

        if categories.isEmpty {
            return [Issue(severity: .error, path: "\(fileName).categories", message: "Categories array is empty.")]
        }

        var issues: [Issue] = []
        var categoryIDs: Set<String> = []

        for (categoryIndex, category) in categories.enumerated() {
            let categoryPath = "categories[\(categoryIndex)]"
            let categoryID = (category["id"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let categoryTitle = (category["title"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let categoryIcon = (category["icon"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

            if categoryID.isEmpty {
                issues.append(Issue(severity: .error, path: "\(categoryPath).id", message: "Category id is empty."))
            } else if categoryIDs.contains(categoryID) {
                issues.append(Issue(severity: .error, path: "\(categoryPath).id", message: "Duplicate category id '\(categoryID)'."))
            } else {
                categoryIDs.insert(categoryID)
            }

            if categoryTitle.isEmpty {
                issues.append(Issue(severity: .error, path: "\(categoryPath).title", message: "Category title is empty."))
            }

            if categoryIcon.isEmpty {
                issues.append(Issue(severity: .warning, path: "\(categoryPath).icon", message: "Category icon is empty."))
            }

            if let deadline = category["deadline"] as? String, !deadline.isEmpty, !isValidDate(deadline) {
                issues.append(Issue(severity: .warning, path: "\(categoryPath).deadline", message: "Deadline is not ISO date (yyyy-MM-dd)."))
            }

            guard let tasks = category["tasks"] as? [[String: Any]] else {
                issues.append(Issue(severity: .warning, path: "\(categoryPath).tasks", message: "Missing tasks array."))
                continue
            }

            if tasks.isEmpty {
                issues.append(Issue(severity: .warning, path: "\(categoryPath).tasks", message: "Category has no tasks."))
            }

            var taskIDs: Set<String> = []
            for (taskIndex, task) in tasks.enumerated() {
                let taskPath = "\(categoryPath).tasks[\(taskIndex)]"
                let taskID = (task["id"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let taskTitle = (task["title"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

                if taskID.isEmpty {
                    issues.append(Issue(severity: .error, path: "\(taskPath).id", message: "Task id is empty."))
                } else if taskIDs.contains(taskID) {
                    issues.append(Issue(severity: .error, path: "\(taskPath).id", message: "Duplicate task id '\(taskID)'."))
                } else {
                    taskIDs.insert(taskID)
                }

                if taskTitle.isEmpty {
                    issues.append(Issue(severity: .error, path: "\(taskPath).title", message: "Task title is empty."))
                }

                collectURLIssues(
                    in: task,
                    path: taskPath,
                    issues: &issues,
                    inheritedTrustType: nil
                )
            }
        }

        return issues
    }

    private static func collectURLIssues(
        in node: Any,
        path: String,
        issues: inout [Issue],
        inheritedTrustType: String?
    ) {
        if let dictionary = node as? [String: Any] {
            let localTrustType = dictionary["sourceType"] as? String
                ?? ((dictionary["source"] as? [String: Any])?["sourceType"] as? String)
                ?? inheritedTrustType

            if let urlString = dictionary["url"] as? String {
                validateURL(
                    urlString,
                    path: "\(path).url",
                    issues: &issues,
                    trustType: localTrustType
                )
            }

            for (key, value) in dictionary {
                collectURLIssues(
                    in: value,
                    path: "\(path).\(key)",
                    issues: &issues,
                    inheritedTrustType: localTrustType
                )
            }

            return
        }

        if let array = node as? [Any] {
            for (index, item) in array.enumerated() {
                collectURLIssues(
                    in: item,
                    path: "\(path)[\(index)]",
                    issues: &issues,
                    inheritedTrustType: inheritedTrustType
                )
            }
        }
    }

    private static func validateURL(
        _ raw: String,
        path: String,
        issues: inout [Issue],
        trustType: String?
    ) {
        guard let url = URL(string: raw), let scheme = url.scheme?.lowercased() else {
            issues.append(Issue(severity: .error, path: path, message: "Invalid URL '\(raw)'."))
            return
        }

        if scheme != "https" && scheme != "http" {
            issues.append(Issue(severity: .error, path: path, message: "Unsupported URL scheme '\(scheme)'."))
            return
        }

        guard let trustType else { return }
        let lowered = trustType.lowercased()
        guard lowered == "official" || lowered == "university" else { return }

        guard let host = url.host?.lowercased() else {
            issues.append(Issue(severity: .warning, path: path, message: "Official/university URL missing host."))
            return
        }

        let isTrusted = trustedOfficialDomainSuffixes.contains(where: { suffix in
            host == suffix || host.hasSuffix(".\(suffix)")
        })

        if !isTrusted {
            issues.append(
                Issue(
                    severity: .warning,
                    path: path,
                    message: "Official/university host '\(host)' is not in trusted suffix list."
                )
            )
        }
    }

    private static func isValidDate(_ raw: String) -> Bool {
        isoDateFormatter.date(from: raw) != nil || fallbackDateFormatter.date(from: raw) != nil
    }

    private static let isoDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter
    }()

    private static let fallbackDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

let args = CommandLine.arguments.dropFirst()
let files: [String]
if args.isEmpty {
    files = ["arrival uk/Data/categories.json", "arrival uk/Data/content.json"]
} else {
    files = Array(args)
}

var totalWarnings = 0
var totalErrors = 0

for file in files {
    guard let data = FileManager.default.contents(atPath: file) else {
        fputs("ERROR \(file): Could not read file.\n", stderr)
        totalErrors += 1
        continue
    }

    let issues = Validator.validate(data: data, fileName: file)
    let warnings = issues.filter { $0.severity == .warning }
    let errors = issues.filter { $0.severity == .error }

    totalWarnings += warnings.count
    totalErrors += errors.count

    print("Validation: \(file)")
    print("  warnings: \(warnings.count)")
    print("  errors: \(errors.count)")
    for issue in issues.prefix(120) {
        print("  [\(issue.severity.rawValue)] \(issue.path): \(issue.message)")
    }
}

if totalErrors > 0 {
    exit(1)
}
exit(0)

```

## arrival uk.xcodeproj/project.pbxproj

```text
// !$*UTF8*$!
{
	archiveVersion = 1;
	classes = {
	};
	objectVersion = 77;
	objects = {

/* Begin PBXBuildFile section */
		A1B2C3D42F00000100AAA111 /* GoogleSignIn in Frameworks */ = {isa = PBXBuildFile; productRef = A1B2C3D52F00000100AAA111 /* GoogleSignIn */; };
		A1B2C3DA2F00000100AAA111 /* FirebaseCore in Frameworks */ = {isa = PBXBuildFile; productRef = A1B2C3D82F00000100AAA111 /* FirebaseCore */; };
		A1B2C3DB2F00000100AAA111 /* FirebaseCrashlytics in Frameworks */ = {isa = PBXBuildFile; productRef = A1B2C3D92F00000100AAA111 /* FirebaseCrashlytics */; };
/* End PBXBuildFile section */

/* Begin PBXBuildRule section */
		C9B6A9372F3177BE00929D9F /* PBXBuildRule */ = {
			isa = PBXBuildRule;
			compilerSpec = com.apple.compilers.proxy.script;
			fileType = folder.rkassets;
			inputFiles = (
			);
			isEditable = 1;
			outputFiles = (
			);
			script = "# realitytool\n";
		};
/* End PBXBuildRule section */

/* Begin PBXFileReference section */
		C9B6A9292F31469600929D9F /* arrival uk.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = "arrival uk.app"; sourceTree = BUILT_PRODUCTS_DIR; };
/* End PBXFileReference section */

/* Begin PBXFileSystemSynchronizedRootGroup section */
		C9B6A92B2F31469600929D9F /* arrival uk */ = {
			isa = PBXFileSystemSynchronizedRootGroup;
			path = "arrival uk";
			sourceTree = "<group>";
		};
/* End PBXFileSystemSynchronizedRootGroup section */

/* Begin PBXFrameworksBuildPhase section */
		C9B6A9262F31469600929D9F /* Frameworks */ = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
				A1B2C3DB2F00000100AAA111 /* FirebaseCrashlytics in Frameworks */,
				A1B2C3DA2F00000100AAA111 /* FirebaseCore in Frameworks */,
				A1B2C3D42F00000100AAA111 /* GoogleSignIn in Frameworks */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		C9B6A9202F31469600929D9F = {
			isa = PBXGroup;
			children = (
				C9B6A92B2F31469600929D9F /* arrival uk */,
				C9B6A92A2F31469600929D9F /* Products */,
			);
			sourceTree = "<group>";
		};
		C9B6A92A2F31469600929D9F /* Products */ = {
			isa = PBXGroup;
			children = (
				C9B6A9292F31469600929D9F /* arrival uk.app */,
			);
			name = Products;
			sourceTree = "<group>";
		};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		C9B6A9282F31469600929D9F /* arrival uk */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = C9B6A9342F31469900929D9F /* Build configuration list for PBXNativeTarget "arrival uk" */;
			buildPhases = (
				C9B6A9252F31469600929D9F /* Sources */,
				C9B6A9262F31469600929D9F /* Frameworks */,
				C9B6A9272F31469600929D9F /* Resources */,
			);
			buildRules = (
				C9B6A9372F3177BE00929D9F /* PBXBuildRule */,
			);
			dependencies = (
			);
			fileSystemSynchronizedGroups = (
				C9B6A92B2F31469600929D9F /* arrival uk */,
			);
			name = "arrival uk";
			packageProductDependencies = (
				A1B2C3D82F00000100AAA111 /* FirebaseCore */,
				A1B2C3D92F00000100AAA111 /* FirebaseCrashlytics */,
				A1B2C3D52F00000100AAA111 /* GoogleSignIn */,
			);
			productName = "arrival uk";
			productReference = C9B6A9292F31469600929D9F /* arrival uk.app */;
			productType = "com.apple.product-type.application";
		};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		C9B6A9212F31469600929D9F /* Project object */ = {
			isa = PBXProject;
			attributes = {
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 2620;
				LastUpgradeCheck = 2620;
				TargetAttributes = {
					C9B6A9282F31469600929D9F = {
						CreatedOnToolsVersion = 26.2;
					};
				};
			};
			buildConfigurationList = C9B6A9242F31469600929D9F /* Build configuration list for PBXProject "arrival uk" */;
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				Base,
			);
			mainGroup = C9B6A9202F31469600929D9F;
			minimizedProjectReferenceProxies = 1;
			packageReferences = (
				A1B2C3D72F00000100AAA111 /* XCRemoteSwiftPackageReference "firebase-ios-sdk" */,
				A1B2C3D62F00000100AAA111 /* XCRemoteSwiftPackageReference "GoogleSignIn-iOS" */,
			);
			preferredProjectObjectVersion = 77;
			productRefGroup = C9B6A92A2F31469600929D9F /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				C9B6A9282F31469600929D9F /* arrival uk */,
			);
		};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
		C9B6A9272F31469600929D9F /* Resources */ = {
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		C9B6A9252F31469600929D9F /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
		C9B6A9322F31469900929D9F /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_ENABLE_OBJC_WEAK = YES;
				CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_COMMA = YES;
				CLANG_WARN_CONSTANT_CONVERSION = YES;
				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
				CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
				CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
				CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
				CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
				CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
				CLANG_WARN_STRICT_PROTOTYPES = YES;
				CLANG_WARN_SUSPICIOUS_MOVE = YES;
				CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
				CLANG_WARN_UNREACHABLE_CODE = YES;
				CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_TESTABILITY = YES;
				ENABLE_USER_SCRIPT_SANDBOXING = YES;
				GCC_C_LANGUAGE_STANDARD = gnu17;
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_OPTIMIZATION_LEVEL = 0;
				GCC_PREPROCESSOR_DEFINITIONS = (
					"DEBUG=1",
					"$(inherited)",
				);
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNDECLARED_SELECTOR = YES;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				LOCALIZATION_PREFERS_STRING_CATALOGS = YES;
				MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
				MTL_FAST_MATH = YES;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = iphoneos;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
			};
			name = Debug;
		};
		C9B6A9332F31469900929D9F /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_ENABLE_OBJC_WEAK = YES;
				CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_COMMA = YES;
				CLANG_WARN_CONSTANT_CONVERSION = YES;
				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
				CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
				CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
				CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
				CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
				CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
				CLANG_WARN_STRICT_PROTOTYPES = YES;
				CLANG_WARN_SUSPICIOUS_MOVE = YES;
				CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
				CLANG_WARN_UNREACHABLE_CODE = YES;
				CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				ENABLE_NS_ASSERTIONS = NO;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_USER_SCRIPT_SANDBOXING = YES;
				GCC_C_LANGUAGE_STANDARD = gnu17;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNDECLARED_SELECTOR = YES;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				LOCALIZATION_PREFERS_STRING_CATALOGS = YES;
				MTL_ENABLE_DEBUG_INFO = NO;
				MTL_FAST_MATH = YES;
				SDKROOT = iphoneos;
				SWIFT_COMPILATION_MODE = wholemodule;
				VALIDATE_PRODUCT = YES;
			};
			name = Release;
		};
		C9B6A9352F31469900929D9F /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ADMOB_APP_ID = "ca-app-pub-3940256099942544~1458002511";
				ADMOB_INTERSTITIAL_UNIT_ID = "ca-app-pub-3940256099942544/4411468910";
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = 7JCVTNXD3U;
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_KEY_GADApplicationIdentifier = "$(ADMOB_APP_ID)";
				INFOPLIST_KEY_NSAppTransportSecurity_NSAllowsArbitraryLoads = NO;
				INFOPLIST_KEY_NSUserTrackingUsageDescription = "We use this permission to show more relevant ads and keep the app free.";
				INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
				INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
				INFOPLIST_KEY_UILaunchScreen_Generation = YES;
				INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = "com.arrivaluk.arrival-uk";
				PRODUCT_NAME = "$(TARGET_NAME)";
				STRING_CATALOG_GENERATE_SYMBOLS = YES;
				SWIFT_APPROACHABLE_CONCURRENCY = YES;
				SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_TREAT_WARNINGS_AS_ERRORS = YES;
				SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";
			};
			name = Debug;
		};
		C9B6A9362F31469900929D9F /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ADMOB_APP_ID = "ca-app-pub-REPLACE_WITH_PRODUCTION_APP_ID";
				ADMOB_INTERSTITIAL_UNIT_ID = "ca-app-pub-REPLACE_WITH_PRODUCTION_INTERSTITIAL_ID";
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = 7JCVTNXD3U;
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_KEY_GADApplicationIdentifier = "$(ADMOB_APP_ID)";
				INFOPLIST_KEY_NSAppTransportSecurity_NSAllowsArbitraryLoads = NO;
				INFOPLIST_KEY_NSUserTrackingUsageDescription = "We use this permission to show more relevant ads and keep the app free.";
				INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
				INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
				INFOPLIST_KEY_UILaunchScreen_Generation = YES;
				INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = "com.arrivaluk.arrival-uk";
				PRODUCT_NAME = "$(TARGET_NAME)";
				STRING_CATALOG_GENERATE_SYMBOLS = YES;
				SWIFT_APPROACHABLE_CONCURRENCY = YES;
				SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_TREAT_WARNINGS_AS_ERRORS = YES;
				SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";
			};
			name = Release;
		};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		C9B6A9242F31469600929D9F /* Build configuration list for PBXProject "arrival uk" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				C9B6A9322F31469900929D9F /* Debug */,
				C9B6A9332F31469900929D9F /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
		C9B6A9342F31469900929D9F /* Build configuration list for PBXNativeTarget "arrival uk" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				C9B6A9352F31469900929D9F /* Debug */,
				C9B6A9362F31469900929D9F /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
/* End XCConfigurationList section */

/* Begin XCRemoteSwiftPackageReference section */
		A1B2C3D72F00000100AAA111 /* XCRemoteSwiftPackageReference "firebase-ios-sdk" */ = {
			isa = XCRemoteSwiftPackageReference;
			repositoryURL = "https://github.com/firebase/firebase-ios-sdk";
			requirement = {
				kind = upToNextMajorVersion;
				minimumVersion = 11.0.0;
			};
		};
		A1B2C3D62F00000100AAA111 /* XCRemoteSwiftPackageReference "GoogleSignIn-iOS" */ = {
			isa = XCRemoteSwiftPackageReference;
			repositoryURL = "https://github.com/google/GoogleSignIn-iOS";
			requirement = {
				kind = upToNextMajorVersion;
				minimumVersion = 7.1.0;
			};
		};
/* End XCRemoteSwiftPackageReference section */

/* Begin XCSwiftPackageProductDependency section */
		A1B2C3D82F00000100AAA111 /* FirebaseCore */ = {
			isa = XCSwiftPackageProductDependency;
			package = A1B2C3D72F00000100AAA111 /* XCRemoteSwiftPackageReference "firebase-ios-sdk" */;
			productName = FirebaseCore;
		};
		A1B2C3D92F00000100AAA111 /* FirebaseCrashlytics */ = {
			isa = XCSwiftPackageProductDependency;
			package = A1B2C3D72F00000100AAA111 /* XCRemoteSwiftPackageReference "firebase-ios-sdk" */;
			productName = FirebaseCrashlytics;
		};
		A1B2C3D52F00000100AAA111 /* GoogleSignIn */ = {
			isa = XCSwiftPackageProductDependency;
			package = A1B2C3D62F00000100AAA111 /* XCRemoteSwiftPackageReference "GoogleSignIn-iOS" */;
			productName = GoogleSignIn;
		};
/* End XCSwiftPackageProductDependency section */
	};
	rootObject = C9B6A9212F31469600929D9F /* Project object */;
}

```

## arrival uk.xcodeproj/project.xcworkspace/contents.xcworkspacedata

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Workspace
   version = "1.0">
   <FileRef
      location = "self:">
   </FileRef>
</Workspace>

```

## arrival uk.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved

```text
{
  "originHash" : "7ed78cec4688813732ed048994a6c24c5c081e333197fce4007040cea0ee7d0c",
  "pins" : [
    {
      "identity" : "abseil-cpp-binary",
      "kind" : "remoteSourceControl",
      "location" : "https://github.com/google/abseil-cpp-binary.git",
      "state" : {
        "revision" : "bbe8b69694d7873315fd3a4ad41efe043e1c07c5",
        "version" : "1.2024072200.0"
      }
    },
    {
      "identity" : "app-check",
      "kind" : "remoteSourceControl",
      "location" : "https://github.com/google/app-check.git",
      "state" : {
        "revision" : "61b85103a1aeed8218f17c794687781505fbbef5",
        "version" : "11.2.0"
      }
    },
    {
      "identity" : "appauth-ios",
      "kind" : "remoteSourceControl",
      "location" : "https://github.com/openid/AppAuth-iOS.git",
      "state" : {
        "revision" : "2781038865a80e2c425a1da12cc1327bcd56501f",
        "version" : "1.7.6"
      }
    },
    {
      "identity" : "firebase-ios-sdk",
      "kind" : "remoteSourceControl",
      "location" : "https://github.com/firebase/firebase-ios-sdk",
      "state" : {
        "revision" : "fdc352fabaf5916e7faa1f96ad02b1957e93e5a5",
        "version" : "11.15.0"
      }
    },
    {
      "identity" : "google-ads-on-device-conversion-ios-sdk",
      "kind" : "remoteSourceControl",
      "location" : "https://github.com/googleads/google-ads-on-device-conversion-ios-sdk",
      "state" : {
        "revision" : "a2d0f1f1666de591eb1a811f40b1706f5c63a2ed",
        "version" : "2.3.0"
      }
    },
    {
      "identity" : "googleappmeasurement",
      "kind" : "remoteSourceControl",
      "location" : "https://github.com/google/GoogleAppMeasurement.git",
      "state" : {
        "revision" : "45ce435e9406d3c674dd249a042b932bee006f60",
        "version" : "11.15.0"
      }
    },
    {
      "identity" : "googledatatransport",
      "kind" : "remoteSourceControl",
      "location" : "https://github.com/google/GoogleDataTransport.git",
      "state" : {
        "revision" : "617af071af9aa1d6a091d59a202910ac482128f9",
        "version" : "10.1.0"
      }
    },
    {
      "identity" : "googlesignin-ios",
      "kind" : "remoteSourceControl",
      "location" : "https://github.com/google/GoogleSignIn-iOS",
      "state" : {
        "revision" : "a7965d134c5d3567026c523e0a8a583f73b62b0d",
        "version" : "7.1.0"
      }
    },
    {
      "identity" : "googleutilities",
      "kind" : "remoteSourceControl",
      "location" : "https://github.com/google/GoogleUtilities.git",
      "state" : {
        "revision" : "60da361632d0de02786f709bdc0c4df340f7613e",
        "version" : "8.1.0"
      }
    },
    {
      "identity" : "grpc-binary",
      "kind" : "remoteSourceControl",
      "location" : "https://github.com/google/grpc-binary.git",
      "state" : {
        "revision" : "75b31c842f664a0f46a2e590a570e370249fd8f6",
        "version" : "1.69.1"
      }
    },
    {
      "identity" : "gtm-session-fetcher",
      "kind" : "remoteSourceControl",
      "location" : "https://github.com/google/gtm-session-fetcher.git",
      "state" : {
        "revision" : "a2ab612cb980066ee56d90d60d8462992c07f24b",
        "version" : "3.5.0"
      }
    },
    {
      "identity" : "gtmappauth",
      "kind" : "remoteSourceControl",
      "location" : "https://github.com/google/GTMAppAuth.git",
      "state" : {
        "revision" : "5d7d66f647400952b1758b230e019b07c0b4b22a",
        "version" : "4.1.1"
      }
    },
    {
      "identity" : "interop-ios-for-google-sdks",
      "kind" : "remoteSourceControl",
      "location" : "https://github.com/google/interop-ios-for-google-sdks.git",
      "state" : {
        "revision" : "040d087ac2267d2ddd4cca36c757d1c6a05fdbfe",
        "version" : "101.0.0"
      }
    },
    {
      "identity" : "leveldb",
      "kind" : "remoteSourceControl",
      "location" : "https://github.com/firebase/leveldb.git",
      "state" : {
        "revision" : "a0bc79961d7be727d258d33d5a6b2f1023270ba1",
        "version" : "1.22.5"
      }
    },
    {
      "identity" : "nanopb",
      "kind" : "remoteSourceControl",
      "location" : "https://github.com/firebase/nanopb.git",
      "state" : {
        "revision" : "b7e1104502eca3a213b46303391ca4d3bc8ddec1",
        "version" : "2.30910.0"
      }
    },
    {
      "identity" : "promises",
      "kind" : "remoteSourceControl",
      "location" : "https://github.com/google/promises.git",
      "state" : {
        "revision" : "540318ecedd63d883069ae7f1ed811a2df00b6ac",
        "version" : "2.4.0"
      }
    },
    {
      "identity" : "swift-protobuf",
      "kind" : "remoteSourceControl",
      "location" : "https://github.com/apple/swift-protobuf.git",
      "state" : {
        "revision" : "c5ab62237f21cad094812719a1bbe29443407c5f",
        "version" : "1.34.1"
      }
    }
  ],
  "version" : 3
}

```

## arrival uk/AdSystem.swift

```swift
import Foundation
import UIKit
import os
#if canImport(AppTrackingTransparency)
import AppTrackingTransparency
#endif

enum AdTopic: String, CaseIterable {
    case education
    case finance
    case transport
    case housing
    case groceries
    case career
    case gambling
    case betting
    case adult
    case dating
    case alcohol
    case tobacco
}

enum AdContentRules {
    static let blockedTopics: Set<AdTopic> = [
        .gambling,
        .betting,
        .adult,
        .dating,
        .alcohol,
        .tobacco
    ]

    static let defaultSafeTopics: Set<AdTopic> = [
        .education,
        .finance,
        .transport,
        .housing,
        .groceries,
        .career
    ]

    static let blockedCategorySummary = "Gambling, betting, adult, dating, alcohol, and tobacco."

    static func allows(topics: Set<AdTopic>) -> Bool {
        !topics.isEmpty && topics.isDisjoint(with: blockedTopics)
    }
}

enum AdEvent: String {
    case appBecameActive = "app_became_active"
    case taskToggled = "task_toggled"
    case taskDetailOpened = "task_detail_opened"
    case personalTaskAdded = "personal_task_added"
    case resourceOpened = "resource_opened"

    var countsAsInteraction: Bool {
        switch self {
        case .taskToggled, .taskDetailOpened, .personalTaskAdded, .resourceOpened:
            return true
        case .appBecameActive:
            return false
        }
    }

    var canTriggerEvaluation: Bool {
        switch self {
        case .taskToggled, .taskDetailOpened, .personalTaskAdded, .resourceOpened:
            return true
        case .appBecameActive:
            return false
        }
    }

    var topics: Set<AdTopic> {
        switch self {
        case .taskToggled, .taskDetailOpened, .personalTaskAdded, .resourceOpened:
            return AdContentRules.defaultSafeTopics
        case .appBecameActive:
            return []
        }
    }
}

enum AdPlacement: String {
    case inlineContextual = "inline_contextual"
}

struct AdOpportunity {
    let placement: AdPlacement
    let sourceEvent: AdEvent
    let topics: Set<AdTopic>
    let issuedAt: Date
}

struct AdPolicyConfig {
    let warmupSeconds: TimeInterval = 180
    let minimumInteractionsBeforeFirstAd: Int = 4
    let minimumSecondsBetweenAds: TimeInterval = 240
    let maxAdsPerSession: Int = 8
    let maxAdsPerRollingHour: Int = 6
}

enum AdHoldReason {
    case nonTriggerEvent
    case warmupNotFinished
    case notEnoughEngagement
    case cooldownActive
    case sessionCapReached
    case hourlyCapReached
    case lowPowerMode
}

enum AdDecision {
    case allow
    case hold(AdHoldReason)
}

enum TrackingAuthorizationState: Int {
    case notDetermined = 0
    case restricted = 1
    case denied = 2
    case authorized = 3
    case unavailable = 4

    var description: String {
        switch self {
        case .notDetermined:
            return "Not determined"
        case .restricted:
            return "Restricted"
        case .denied:
            return "Denied"
        case .authorized:
            return "Authorized"
        case .unavailable:
            return "Unavailable"
        }
    }
}

@Observable
final class AdPreferencesStore {
    static let shared = AdPreferencesStore()

    private let defaults = UserDefaults.standard
    private let wantsPersonalizedAdsKey = "ads.wantsPersonalizedAds"
    private let trackingStateKey = "ads.trackingAuthorizationState"
    private let hasAcceptedDisclosureKey = "ads.hasAcceptedDisclosure"

    private var hasBootstrapped = false

    var wantsPersonalizedAds: Bool = false
    var trackingAuthorizationState: TrackingAuthorizationState = .notDetermined
    var hasAcceptedDisclosure: Bool = false

    var trackingStatusDescription: String {
        trackingAuthorizationState.description
    }

    var needsInitialDisclosure: Bool {
        !hasAcceptedDisclosure
    }

    var effectivePersonalizedAdsEnabled: Bool {
        wantsPersonalizedAds && trackingAuthorizationState == .authorized
    }

    private init() {
        wantsPersonalizedAds = defaults.bool(forKey: wantsPersonalizedAdsKey)
        hasAcceptedDisclosure = defaults.bool(forKey: hasAcceptedDisclosureKey)
        let rawState = defaults.integer(forKey: trackingStateKey)
        trackingAuthorizationState = TrackingAuthorizationState(rawValue: rawState) ?? .notDetermined
    }

    @MainActor
    func bootstrapIfNeeded() {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true
        refreshTrackingStatusFromSystem()
    }

    @MainActor
    func updateDisclosureAccepted() {
        hasAcceptedDisclosure = true
        persist()
    }

    @MainActor
    func resetPrivacyChoices() {
        wantsPersonalizedAds = false
        hasAcceptedDisclosure = false
        refreshTrackingStatusFromSystem()
        persist()
    }

    @MainActor
    func setPersonalizedAdsRequested(_ enabled: Bool) async {
        updateDisclosureAccepted()
        wantsPersonalizedAds = enabled

        if enabled {
            let newStatus = await requestTrackingAuthorizationIfPossible()
            trackingAuthorizationState = newStatus
            if newStatus != .authorized {
                wantsPersonalizedAds = false
            }
        } else {
            refreshTrackingStatusFromSystem()
        }

        persist()
    }

    @MainActor
    func refreshTrackingStatusFromSystem() {
        trackingAuthorizationState = Self.currentTrackingAuthorizationState()
        persist()
    }

    @MainActor
    private func persist() {
        defaults.set(wantsPersonalizedAds, forKey: wantsPersonalizedAdsKey)
        defaults.set(hasAcceptedDisclosure, forKey: hasAcceptedDisclosureKey)
        defaults.set(trackingAuthorizationState.rawValue, forKey: trackingStateKey)
    }

    @MainActor
    private func requestTrackingAuthorizationIfPossible() async -> TrackingAuthorizationState {
        #if canImport(AppTrackingTransparency)
        if #available(iOS 14, *) {
            guard Bundle.main.object(forInfoDictionaryKey: "NSUserTrackingUsageDescription") != nil else {
                return .denied
            }

            let result = await withCheckedContinuation { continuation in
                ATTrackingManager.requestTrackingAuthorization { status in
                    continuation.resume(returning: status)
                }
            }
            return Self.mapTrackingStatus(result)
        }
        #endif

        return .unavailable
    }

    private static func currentTrackingAuthorizationState() -> TrackingAuthorizationState {
        #if canImport(AppTrackingTransparency)
        if #available(iOS 14, *) {
            return mapTrackingStatus(ATTrackingManager.trackingAuthorizationStatus)
        }
        #endif

        return .unavailable
    }

    #if canImport(AppTrackingTransparency)
    @available(iOS 14, *)
    private static func mapTrackingStatus(
        _ status: ATTrackingManager.AuthorizationStatus
    ) -> TrackingAuthorizationState {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        case .denied:
            return .denied
        case .authorized:
            return .authorized
        @unknown default:
            return .unavailable
        }
    }
    #endif
}

@Observable
final class AdCoordinator {
    private(set) var sessionStartedAt: Date?
    private(set) var interactionCount = 0
    private(set) var opportunitiesIssued = 0
    private(set) var lastOpportunityAt: Date?

    private var recentOpportunityDates: [Date] = []

    private let config = AdPolicyConfig()
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.arrivaluk.app",
        category: "ad-policy"
    )

    @MainActor
    func startSessionIfNeeded(now: Date = .now) {
        guard sessionStartedAt == nil else { return }
        sessionStartedAt = now
        LaunchMetrics.mark(event: "ad_session_started")
    }

    @MainActor
    func register(event: AdEvent, now: Date = .now) -> AdOpportunity? {
        startSessionIfNeeded(now: now)

        if event.countsAsInteraction {
            interactionCount += 1
        }

        switch evaluate(event: event, now: now) {
        case .allow:
            pruneHourlyWindow(reference: now)
            opportunitiesIssued += 1
            lastOpportunityAt = now
            recentOpportunityDates.append(now)

            #if DEBUG
            logger.debug(
                "ad_allowed event=\(event.rawValue, privacy: .public) issued=\(self.opportunitiesIssued)"
            )
            #endif

            return AdOpportunity(
                placement: .inlineContextual,
                sourceEvent: event,
                topics: event.topics,
                issuedAt: now
            )
        case .hold:
            return nil
        }
    }

    @MainActor
    private func evaluate(event: AdEvent, now: Date) -> AdDecision {
        guard event.canTriggerEvaluation else { return .hold(.nonTriggerEvent) }
        guard let sessionStartedAt else { return .hold(.warmupNotFinished) }

        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            return .hold(.lowPowerMode)
        }

        if now.timeIntervalSince(sessionStartedAt) < config.warmupSeconds {
            return .hold(.warmupNotFinished)
        }

        if interactionCount < config.minimumInteractionsBeforeFirstAd {
            return .hold(.notEnoughEngagement)
        }

        if opportunitiesIssued >= config.maxAdsPerSession {
            return .hold(.sessionCapReached)
        }

        if let lastOpportunityAt,
           now.timeIntervalSince(lastOpportunityAt) < config.minimumSecondsBetweenAds {
            return .hold(.cooldownActive)
        }

        pruneHourlyWindow(reference: now)
        if recentOpportunityDates.count >= config.maxAdsPerRollingHour {
            return .hold(.hourlyCapReached)
        }

        return .allow
    }

    @MainActor
    private func pruneHourlyWindow(reference: Date) {
        let cutoff = reference.addingTimeInterval(-3600)
        recentOpportunityDates.removeAll { $0 < cutoff }
    }
}

struct AdConsentSnapshot {
    let effectivePersonalizedAdsEnabled: Bool
}

struct AdRequestContext {
    let placement: AdPlacement
    let sourceEvent: AdEvent
    let topics: Set<AdTopic>
    let nonPersonalized: Bool
}

private protocol AdNetworkClient {
    func configureIfNeeded(consent: AdConsentSnapshot)
    func updateConsent(_ consent: AdConsentSnapshot)
    func requestAd(context: AdRequestContext)
}

final class NoOpAdNetworkClient: AdNetworkClient {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.arrivaluk.app",
        category: "ad-runtime-noop"
    )

    func configureIfNeeded(consent: AdConsentSnapshot) {
        #if DEBUG
        logger.debug("ad_client_noop_configured personalized=\(consent.effectivePersonalizedAdsEnabled)")
        #endif
    }

    func updateConsent(_ consent: AdConsentSnapshot) {
        #if DEBUG
        logger.debug("ad_client_noop_consent_updated personalized=\(consent.effectivePersonalizedAdsEnabled)")
        #endif
    }

    func requestAd(context: AdRequestContext) {
        #if DEBUG
        logger.debug(
            "ad_client_noop_request placement=\(context.placement.rawValue, privacy: .public) event=\(context.sourceEvent.rawValue, privacy: .public)"
        )
        #endif
    }
}

#if canImport(GoogleMobileAds)
import GoogleMobileAds

final class GoogleMobileAdsClient: NSObject, AdNetworkClient {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.arrivaluk.app",
        category: "ad-runtime-gma"
    )

    private var isConfigured = false
    private var latestConsent = AdConsentSnapshot(effectivePersonalizedAdsEnabled: false)
    private var cachedInterstitial: GADInterstitialAd?

    private var adUnitID: String {
        let configured = Bundle.main.object(forInfoDictionaryKey: "ADMOB_INTERSTITIAL_UNIT_ID") as? String
        if let configured, !configured.isEmpty {
            return configured
        }
        #if DEBUG
        return "ca-app-pub-3940256099942544/4411468910"
        #else
        return ""
        #endif
    }

    func configureIfNeeded(consent: AdConsentSnapshot) {
        latestConsent = consent
        guard !isConfigured else { return }
        isConfigured = true

        GADMobileAds.sharedInstance().start(completionHandler: nil)

        #if DEBUG
        logger.debug("gma_started")
        #endif
    }

    func updateConsent(_ consent: AdConsentSnapshot) {
        latestConsent = consent
    }

    func requestAd(context: AdRequestContext) {
        guard isConfigured else {
            configureIfNeeded(consent: latestConsent)
            return
        }

        guard !adUnitID.isEmpty else {
            #if DEBUG
            logger.debug("gma_request_skipped_missing_release_ad_unit_id")
            #endif
            return
        }

        let request = GADRequest()
        request.keywords = context.topics.map(\.rawValue)

        if context.nonPersonalized {
            let extras = GADExtras()
            extras.additionalParameters = ["npa": "1"]
            request.register(extras)
        }

        GADInterstitialAd.load(withAdUnitID: adUnitID, request: request) { [weak self] ad, error in
            guard let self else { return }
            if let error {
                #if DEBUG
                self.logger.debug("gma_load_failed \(error.localizedDescription, privacy: .public)")
                #endif
                return
            }

            self.cachedInterstitial = ad
            #if DEBUG
            self.logger.debug("gma_interstitial_loaded")
            #endif
        }
    }
}
#endif

enum AdLegal {
    static let privacyPolicyURL = AppConfig.legal.privacyPolicyURL.absoluteString
    static let termsOfServiceURL = AppConfig.legal.termsOfServiceURL.absoluteString
    static let supportURL = AppConfig.legal.supportWebsiteURL.absoluteString
    static let dataDeletionURL = AppConfig.legal.dataDeletionRequestURL.absoluteString
}

enum AdRuntime {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.arrivaluk.app",
        category: "ad-runtime"
    )

    private static let preferences = AdPreferencesStore.shared
    private static var bootstrapped = false

    private static let adClient: any AdNetworkClient = {
        #if canImport(GoogleMobileAds)
        return GoogleMobileAdsClient()
        #else
        return NoOpAdNetworkClient()
        #endif
    }()

    @MainActor
    static func bootstrapIfNeeded() {
        guard !bootstrapped else { return }
        bootstrapped = true

        preferences.bootstrapIfNeeded()
        adClient.configureIfNeeded(consent: consentSnapshot())
    }

    @MainActor
    static func updateConsentConfiguration() {
        preferences.refreshTrackingStatusFromSystem()
        adClient.updateConsent(consentSnapshot())
    }

    @MainActor
    static func requestAd(for opportunity: AdOpportunity) {
        bootstrapIfNeeded()

        guard AdContentRules.allows(topics: opportunity.topics) else {
            #if DEBUG
            logger.debug("ad_request_blocked_by_category_filter")
            #endif
            return
        }

        let context = AdRequestContext(
            placement: opportunity.placement,
            sourceEvent: opportunity.sourceEvent,
            topics: opportunity.topics,
            nonPersonalized: !preferences.effectivePersonalizedAdsEnabled
        )

        adClient.requestAd(context: context)

        #if DEBUG
        logger.debug(
            "ad_request placement=\(opportunity.placement.rawValue, privacy: .public) source=\(opportunity.sourceEvent.rawValue, privacy: .public)"
        )
        #endif
    }

    @MainActor
    private static func consentSnapshot() -> AdConsentSnapshot {
        AdConsentSnapshot(
            effectivePersonalizedAdsEnabled: preferences.effectivePersonalizedAdsEnabled
        )
    }
}

```

## arrival uk/Assets.xcassets/AccentColor.colorset/Contents.json

```json
{
  "colors" : [
    {
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}

```

## arrival uk/Assets.xcassets/AppIcon.appiconset/Contents.json

```json
{
  "images" : [
    {
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "tinted"
        }
      ],
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}

```

## arrival uk/Assets.xcassets/Contents.json

```json
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}

```

## arrival uk/Auth/AuthStateValidator.swift

```swift
import Foundation

struct AuthStateValidator {
    static func normalize(_ snapshot: StudentProfileSnapshot) -> StudentProfileSnapshot {
        var normalized = snapshot

        switch snapshot.authProvider {
        case .none:
            normalized.appleUserID = nil
            normalized.googleUserID = nil

        case .apple:
            let appleID = snapshot.appleUserID?.trimmingCharacters(in: .whitespacesAndNewlines)
            if appleID?.isEmpty ?? true {
                normalized.authProvider = .none
                normalized.appleUserID = nil
                normalized.email = ""
            }
            normalized.googleUserID = nil

        case .google:
            let googleID = snapshot.googleUserID?.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedEmail = snapshot.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

            // Google mode is valid with either Google user ID or a valid email fallback.
            let hasValidGoogleIdentity = !(googleID?.isEmpty ?? true) || normalizedEmail.contains("@")
            if !hasValidGoogleIdentity {
                normalized.authProvider = .none
                normalized.googleUserID = nil
                normalized.email = ""
            }
            normalized.appleUserID = nil
        }

        // Keep profile completion state coherent.
        if normalized.fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            normalized.selectedUniversity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            normalized.hasCompletedSetup = false
        }

        return normalized
    }
}

```

## arrival uk/Auth/AuthenticationManager.swift

```swift
import Foundation
import Combine

#if canImport(FirebaseAuth) && canImport(FirebaseFirestore) && canImport(FirebaseFunctions)
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions

@available(iOS 17.0, *)
@MainActor
final class AuthenticationManager: ObservableObject {
    static let shared = AuthenticationManager()

    @Published private(set) var currentUser: User?
    @Published private(set) var isAuthenticated = false

    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    private let functions = Functions.functions()

    private var listenerHandle: AuthStateDidChangeListenerHandle?

    private init() {
        listenerHandle = auth.addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            Task { @MainActor in
                self.currentUser = user
                self.isAuthenticated = user != nil
                if let user {
                    await self.syncUserProfile(userId: user.uid)
                }
            }
        }
    }

    deinit {
        if let listenerHandle {
            auth.removeStateDidChangeListener(listenerHandle)
        }
    }

    func signOut() throws {
        Task {
            await PushNotificationManager.shared.unregisterDeviceTokenFromBackend()
        }
        try auth.signOut()
        currentUser = nil
        isAuthenticated = false
    }

    func deleteAccount() async throws {
        guard let user = currentUser else {
            throw AuthBridgeError.notAuthenticated
        }
        try await user.delete()
        currentUser = nil
        isAuthenticated = false
    }

    func trackLogin(platform: String = "ios") async {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        do {
            _ = try await functions.httpsCallable("trackLogin").call([
                "platform": platform,
                "appVersion": version,
            ])
        } catch {
            CrashReporter.record(error: error, context: "auth_track_login")
        }
    }

    func verifyUserProfile() async {
        do {
            _ = try await functions.httpsCallable("verifyUser").call([:])
        } catch {
            CrashReporter.record(error: error, context: "auth_verify_user")
        }
    }

    private func syncUserProfile(userId: String) async {
        do {
            let document = try await db.collection("users").document(userId).getDocument()
            guard let payload = document.data() else { return }
            StudentProfileStore.shared.syncFromRemote(payload)
        } catch {
            CrashReporter.record(error: error, context: "auth_sync_profile")
        }
    }
}

enum AuthBridgeError: LocalizedError {
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User is not authenticated."
        }
    }
}

@available(iOS 17.0, *)
extension StudentProfileStore {
    @MainActor
    func syncFromRemote(_ payload: [String: Any]) {
        // Intentionally conservative mapping: only sync known safe profile fields.
        if let fullName = payload["displayName"] as? String,
           self.fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.fullName = fullName
        }

        if let email = payload["email"] as? String,
           !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.email = email
        }

        if let profile = payload["profile"] as? [String: Any] {
            if let university = profile["university"] as? String,
               !university.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.selectedUniversity = university
            }
            if let city = profile["city"] as? String,
               !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.city = city
            }
            if let course = profile["course"] as? String,
               !course.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.courseName = course
            }
        }

        // Persist through existing local serialization path.
        self.updateProfile(
            fullName: self.fullName,
            selectedUniversity: self.selectedUniversity,
            courseName: self.courseName,
            city: self.city,
            studyLevel: self.studyLevel,
            arrivalDate: self.arrivalDate
        )
    }
}

#else

@available(iOS 17.0, *)
@MainActor
final class AuthenticationManager: ObservableObject {
    static let shared = AuthenticationManager()

    @Published private(set) var currentUser: Any?
    @Published private(set) var isAuthenticated = false

    private init() {}

    func signOut() throws {}
    func deleteAccount() async throws {}
    func trackLogin(platform: String = "ios") async {}
    func verifyUserProfile() async {}
}

#endif

```

## arrival uk/ContentData.swift

```swift
import Foundation
import Observation
import os

@Observable
final class ContentStore {
    static let shared = ContentStore()

    var categories: [ChecklistCategory] = []
    private let progressKey = "content.store.progress.v1"
    private var cachedProgressSnapshot: ContentProgressSnapshot?
    
    private struct BundleLoadResolution {
        let categories: [ChecklistCategory]
        let event: String
    }

    @MainActor
    func loadFromBundle() async {
        LaunchMetrics.mark(event: "bundle_content_load_begin")
        let storageKey = progressKey
        let (resolution, snapshot) = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let resolved = Self.resolveCategoriesFromBundle()
                let snapshot = Self.decodeProgressSnapshot(storageKey: storageKey)
                continuation.resume(returning: (resolved, snapshot))
            }
        }

        cachedProgressSnapshot = snapshot
        categories = resolution.categories
        applyPersistedProgressIfAvailable()
        LaunchMetrics.mark(event: resolution.event)
    }

    @MainActor
    func primeWithSampleDataIfNeeded() {
        guard categories.isEmpty else { return }
        categories = Self.normalizedCategories(Self.sanitize(SampleData.categories))
        applyPersistedProgressIfAvailable()
        LaunchMetrics.mark(event: "bundle_content_primed_sample")
    }

    @MainActor
    func persistProgress() {
        guard !categories.isEmpty else { return }
        let categorySnapshot = categories
        let storageKey = progressKey

        DispatchQueue.global(qos: .utility).async {
            let completedTaskIDs = categorySnapshot
                .flatMap(\.tasks)
                .filter(\.isComplete)
                .map(\.id)

            var customTasksByCategory: [String: [ChecklistTask]] = [:]
            for category in categorySnapshot {
                let customTasks = category.tasks.filter(\.isCustom)
                if !customTasks.isEmpty {
                    customTasksByCategory[category.id] = customTasks
                }
            }

            let snapshot = ContentProgressSnapshot(
                completedTaskIDs: completedTaskIDs,
                customTasksByCategory: customTasksByCategory
            )

            guard let encoded = try? JSONEncoder().encode(snapshot) else {
                LaunchMetrics.mark(event: "content_progress_encode_failed")
                return
            }

            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }

    @MainActor
    func clearAllProgress() {
        guard !categories.isEmpty else {
            UserDefaults.standard.removeObject(forKey: progressKey)
            cachedProgressSnapshot = nil
            return
        }

        for categoryIndex in categories.indices {
            categories[categoryIndex].tasks.removeAll(where: \.isCustom)
            for taskIndex in categories[categoryIndex].tasks.indices {
                categories[categoryIndex].tasks[taskIndex].isComplete = false
            }
        }

        cachedProgressSnapshot = nil
        UserDefaults.standard.removeObject(forKey: progressKey)
    }

    @MainActor
    private func applyPersistedProgressIfAvailable() {
        if let cachedProgressSnapshot {
            applyPersistedProgress(cachedProgressSnapshot)
            return
        }

        guard let snapshot = Self.decodeProgressSnapshot(storageKey: progressKey) else { return }
        cachedProgressSnapshot = snapshot
        applyPersistedProgress(snapshot)
    }

    @MainActor
    private func applyPersistedProgress(_ snapshot: ContentProgressSnapshot) {
        let completedTaskIDs = Set(snapshot.completedTaskIDs)
        var updatedCategories: [ChecklistCategory] = []

        for var category in categories {
            if let savedCustomTasks = snapshot.customTasksByCategory[category.id], !savedCustomTasks.isEmpty {
                let existingIDs = Set(category.tasks.map(\.id))
                let missingCustomTasks = savedCustomTasks.filter { !existingIDs.contains($0.id) }
                category.tasks.append(contentsOf: missingCustomTasks)
            }

            for index in category.tasks.indices {
                category.tasks[index].isComplete = completedTaskIDs.contains(category.tasks[index].id)
            }

            updatedCategories.append(category)
        }

        categories = Self.normalizedCategories(updatedCategories)
        LaunchMetrics.mark(event: "content_progress_applied")
    }

    private static func decodeProgressSnapshot(storageKey: String) -> ContentProgressSnapshot? {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let snapshot = try? JSONDecoder().decode(ContentProgressSnapshot.self, from: data)
        else {
            return nil
        }

        return snapshot
    }

    private static func resolveCategoriesFromBundle() -> BundleLoadResolution {
        // Fast path: prefer content.json first because it already carries structured sections.
        // Decoding only one file significantly reduces cold-start time on simulator.
        if var contentPayload = ContentPayload.loadFromBundle(named: "content"),
           !contentPayload.categories.isEmpty {
            // Ensure minimal fallback guidance is still present if structured content is partial.
            contentPayload = mergePayload(
                primary: contentPayload,
                secondary: ContentPayload(categories: SampleData.categories),
                includeFallbackOnlyTasks: false,
                includeFallbackOnlyCategories: false
            )

            let resolvedCategories = normalizedCategories(sanitize(contentPayload.categories))
            logIntegrityReport(for: resolvedCategories, source: "content")
            let totalTasks = resolvedCategories.reduce(0) { $0 + $1.tasks.count }
            if totalTasks > 0 {
                return BundleLoadResolution(
                    categories: resolvedCategories,
                    event: "bundle_content_load_success_content_tasks_\(totalTasks)"
                )
            }
        }

        // Fallback path: categories.json (legacy schema) + sample enrichment for task detail guidance.
        if var categoriesPayload = ContentPayload.loadFromBundle(named: "categories"),
           !categoriesPayload.categories.isEmpty {
            categoriesPayload = mergePayload(
                primary: categoriesPayload,
                secondary: ContentPayload(categories: SampleData.categories),
                includeFallbackOnlyTasks: false,
                includeFallbackOnlyCategories: false
            )
            LaunchMetrics.mark(event: "bundle_content_enriched_with_sample_fallback")

            let resolvedCategories = normalizedCategories(sanitize(categoriesPayload.categories))
            logIntegrityReport(for: resolvedCategories, source: "categories")
            let totalTasks = resolvedCategories.reduce(0) { $0 + $1.tasks.count }
            if totalTasks > 0 {
                return BundleLoadResolution(
                    categories: resolvedCategories,
                    event: "bundle_content_load_success_categories_tasks_\(totalTasks)"
                )
            }
        }

        let resolvedCategories = normalizedCategories(sanitize(SampleData.categories))
        logIntegrityReport(for: resolvedCategories, source: "sample")
        let totalTasks = resolvedCategories.reduce(0) { $0 + $1.tasks.count }
        let event = totalTasks > 0
            ? "bundle_content_load_fallback_sample_tasks_\(totalTasks)"
            : "bundle_content_load_fallback_sample_empty_tasks"
        return BundleLoadResolution(categories: resolvedCategories, event: event)
    }

    private static func normalizedCategories(_ input: [ChecklistCategory]) -> [ChecklistCategory] {
        let sortedCategories = input.sorted { left, right in
            let leftOrder = left.order ?? Int.max
            let rightOrder = right.order ?? Int.max
            if leftOrder != rightOrder {
                return leftOrder < rightOrder
            }

            let leftPriority = left.visualPriority.ranking
            let rightPriority = right.visualPriority.ranking
            if leftPriority != rightPriority {
                return leftPriority < rightPriority
            }

            let leftUrgency = left.urgencyBand.ranking
            let rightUrgency = right.urgencyBand.ranking
            if leftUrgency != rightUrgency {
                return leftUrgency < rightUrgency
            }

            return left.title.localizedCaseInsensitiveCompare(right.title) == .orderedAscending
        }

        return sortedCategories.map { category in
            var updatedCategory = category
            updatedCategory.tasks = category.tasks.sorted { left, right in
                let leftOrder = left.order ?? Int.max
                let rightOrder = right.order ?? Int.max

                if leftOrder != rightOrder {
                    return leftOrder < rightOrder
                }

                return left.title.localizedCaseInsensitiveCompare(right.title) == .orderedAscending
            }
            return updatedCategory
        }
    }

    private static func sanitize(_ input: [ChecklistCategory]) -> [ChecklistCategory] {
        var seenCategoryIDs: Set<String> = []
        var output: [ChecklistCategory] = []

        for var category in input {
            let categoryID = category.id.trimmingCharacters(in: .whitespacesAndNewlines)
            let canonicalCategoryID = canonical(categoryID)
            let categoryTitle = category.title.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !categoryID.isEmpty, !categoryTitle.isEmpty else {
                continue
            }

            guard !seenCategoryIDs.contains(canonicalCategoryID) else {
                continue
            }

            seenCategoryIDs.insert(canonicalCategoryID)
            category.title = categoryTitle

            if category.icon.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                category.icon = "square.grid.2x2"
            }

            var seenTaskIDs: Set<String> = []
            var cleanedTasks: [ChecklistTask] = []

            for var task in category.tasks {
                let taskID = task.id.trimmingCharacters(in: .whitespacesAndNewlines)
                let canonicalTaskID = canonical(taskID)
                let taskTitle = task.title.trimmingCharacters(in: .whitespacesAndNewlines)

                guard !taskID.isEmpty, !taskTitle.isEmpty else {
                    continue
                }

                guard !seenTaskIDs.contains(canonicalTaskID) else {
                    continue
                }

                seenTaskIDs.insert(canonicalTaskID)
                task.title = taskTitle
                task.detail = task.detail?.trimmingCharacters(in: .whitespacesAndNewlines)
                task.content = normalizedTaskContent(for: task)
                cleanedTasks.append(task)
            }

            category.tasks = cleanedTasks
            output.append(category)
        }

        return output
    }

    private static func mergePayload(
        primary: ContentPayload,
        secondary: ContentPayload,
        includeFallbackOnlyTasks: Bool = false,
        includeFallbackOnlyCategories: Bool = false
    ) -> ContentPayload {
        var secondaryByID: [String: ChecklistCategory] = [:]
        var secondaryByTitle: [String: ChecklistCategory] = [:]

        for category in secondary.categories {
            let canonicalID = canonical(category.id)
            let canonicalTitle = canonical(category.title)
            if secondaryByID[canonicalID] == nil {
                secondaryByID[canonicalID] = category
            }
            if secondaryByTitle[canonicalTitle] == nil {
                secondaryByTitle[canonicalTitle] = category
            }
        }

        var mergedCategories: [ChecklistCategory] = []
        var seenMergedKeys: Set<String> = []

        for category in primary.categories {
            var mergedCategory = category
            let lookupID = canonical(category.id)
            let lookupTitle = canonical(category.title)
            if seenMergedKeys.contains(lookupID) || seenMergedKeys.contains(lookupTitle) {
                continue
            }

            let fallbackCategory = secondaryByID[lookupID] ?? secondaryByTitle[lookupTitle]
            if let fallbackCategory {
                mergedCategory = mergeCategory(
                    primary: mergedCategory,
                    fallback: fallbackCategory,
                    includeFallbackOnlyTasks: includeFallbackOnlyTasks
                )
            }

            mergedCategories.append(mergedCategory)
            seenMergedKeys.insert(lookupID)
            seenMergedKeys.insert(lookupTitle)
        }

        if includeFallbackOnlyCategories {
            for fallbackCategory in secondary.categories {
                let fallbackID = canonical(fallbackCategory.id)
                let fallbackTitle = canonical(fallbackCategory.title)
                if seenMergedKeys.contains(fallbackID) || seenMergedKeys.contains(fallbackTitle) {
                    continue
                }
                mergedCategories.append(fallbackCategory)
            }
        }

        return ContentPayload(categories: mergedCategories)
    }

    private static func mergeCategory(
        primary: ChecklistCategory,
        fallback: ChecklistCategory,
        includeFallbackOnlyTasks: Bool = false
    ) -> ChecklistCategory {
        var merged = primary

        if (merged.subtitle?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) {
            merged.subtitle = fallback.subtitle
        }

        if (merged.categoryType?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) {
            merged.categoryType = fallback.categoryType
        }

        if merged.icon.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || merged.icon == "square.grid.2x2" {
            merged.icon = fallback.icon
        }

        if merged.gradient?.isEmpty ?? true {
            merged.gradient = fallback.gradient
        }

        if merged.priority == nil && merged.priorityLevel == nil {
            merged.priority = fallback.priority
            merged.priorityLevel = fallback.priorityLevel
        }

        if merged.urgency == nil {
            merged.urgency = fallback.urgency
        }

        if (merged.accentColorHex?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) {
            merged.accentColorHex = fallback.accentColorHex
        }

        if (merged.deadline?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) {
            merged.deadline = fallback.deadline
        }

        if merged.order == nil {
            merged.order = fallback.order
        }

        if merged.cityFilters?.isEmpty ?? true {
            merged.cityFilters = fallback.cityFilters
        }

        if merged.universityFilters?.isEmpty ?? true {
            merged.universityFilters = fallback.universityFilters
        }

        if (merged.unlockRequirements?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) {
            merged.unlockRequirements = fallback.unlockRequirements
        }

        if merged.tasks.isEmpty {
            merged.tasks = fallback.tasks
            return merged
        }

        var fallbackTasksByID: [String: ChecklistTask] = [:]
        var fallbackTasksByTitle: [String: ChecklistTask] = [:]
        for fallbackTask in fallback.tasks {
            let canonicalID = canonical(fallbackTask.id)
            if fallbackTasksByID[canonicalID] == nil {
                fallbackTasksByID[canonicalID] = fallbackTask
            }

            let canonicalTitle = canonical(fallbackTask.title)
            if fallbackTasksByTitle[canonicalTitle] == nil {
                fallbackTasksByTitle[canonicalTitle] = fallbackTask
            }
        }

        var mergedTasks: [ChecklistTask] = []
        var mergedTaskIdentifiers: Set<String> = []
        var mergedTaskTitles: Set<String> = []

        for task in merged.tasks {
            let taskID = canonical(task.id)
            let taskTitle = canonical(task.title)

            if let fallbackTask = fallbackTasksByID[taskID] ?? fallbackTasksByTitle[taskTitle] {
                let mergedTask = mergeTask(primary: task, fallback: fallbackTask)
                mergedTasks.append(mergedTask)
                mergedTaskIdentifiers.insert(canonical(mergedTask.id))
                mergedTaskTitles.insert(canonical(mergedTask.title))
            } else {
                mergedTasks.append(task)
                mergedTaskIdentifiers.insert(taskID)
                mergedTaskTitles.insert(taskTitle)
            }
        }

        if includeFallbackOnlyTasks {
            for fallbackTask in fallback.tasks {
                let fallbackID = canonical(fallbackTask.id)
                let fallbackTitle = canonical(fallbackTask.title)
                if mergedTaskIdentifiers.contains(fallbackID) || mergedTaskTitles.contains(fallbackTitle) {
                    continue
                }
                mergedTasks.append(fallbackTask)
                mergedTaskIdentifiers.insert(fallbackID)
                mergedTaskTitles.insert(fallbackTitle)
            }
        }

        merged.tasks = mergedTasks
        return merged
    }

    private static func mergeTask(primary: ChecklistTask, fallback: ChecklistTask) -> ChecklistTask {
        var merged = primary

        if merged.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            merged.title = fallback.title
        }

        if (merged.detail?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) {
            merged.detail = fallback.detail
        }

        if merged.estimatedMinutes == nil {
            merged.estimatedMinutes = fallback.estimatedMinutes
        }

        if merged.order == nil {
            merged.order = fallback.order
        }

        if (merged.sourceTitle?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) {
            merged.sourceTitle = fallback.sourceTitle
        }

        if (merged.sourceURL?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) {
            merged.sourceURL = fallback.sourceURL
        }

        if merged.timing == .anytime && fallback.timing != .anytime {
            merged.timing = fallback.timing
        }

        if merged.priority == .shouldDo && fallback.priority != .shouldDo {
            merged.priority = fallback.priority
        }

        if merged.urgency == .medium && fallback.urgency != .medium {
            merged.urgency = fallback.urgency
        }

        let primarySectionCount = merged.content?.sections.count ?? 0
        let fallbackSectionCount = fallback.content?.sections.count ?? 0
        if fallbackSectionCount > primarySectionCount {
            merged.content = fallback.content
        }

        return merged
    }

    private static func normalizedTaskContent(for task: ChecklistTask) -> TaskContent? {
        if let existingContent = task.content, !existingContent.sections.isEmpty {
            return existingContent
        }

        var sections: [ContentSection] = []
        if let detail = task.detail?.trimmingCharacters(in: .whitespacesAndNewlines), !detail.isEmpty {
            sections.append(
                .overview(
                    OverviewSectionData(
                        title: "Overview",
                        description: nil,
                        content: detail
                    )
                )
            )

            let steps = fallbackStepItems(for: detail)
            if !steps.isEmpty {
                sections.append(
                    .steps(
                        StepsSectionData(
                            type: "steps",
                            title: "Step-by-step",
                            description: nil,
                            items: steps
                        )
                    )
                )
            }
        }

        let tips = fallbackTips(for: task)
        if !tips.isEmpty {
            sections.append(
                .tips(
                    TipsSectionData(
                        type: "tips",
                        title: "Tips",
                        description: nil,
                        items: tips
                    )
                )
            )
        }

        if let rawSourceURL = task.sourceURL?.trimmingCharacters(in: .whitespacesAndNewlines),
           !rawSourceURL.isEmpty,
           let validatedSourceURL = ExternalURLPolicy.normalizedURL(from: rawSourceURL) {
            let sourceTitle = task.sourceTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
            let referenceTitle = sourceTitle?.isEmpty == false ? sourceTitle ?? "Official guidance" : "Official guidance"
            sections.append(
                .references(
                    ReferencesSectionData(
                        type: "references",
                        title: "Official resources",
                        description: nil,
                        items: [
                            ReferenceItem(
                                title: referenceTitle,
                                description: "Open the latest official guidance for this task.",
                                url: validatedSourceURL.absoluteString,
                                type: "official",
                                icon: nil,
                                organization: nil,
                                source: SourceMetadata(
                                    sourceType: .official,
                                    sourceName: nil,
                                    lastVerified: nil,
                                    audience: nil,
                                    note: nil
                                ),
                                audience: nil
                            )
                        ]
                    )
                )
            )
        }

        guard !sections.isEmpty else { return task.content }
        return TaskContent(type: .richGuide, sections: sections)
    }

    private static func fallbackStepItems(for detail: String) -> [ProcessStepItem] {
        let normalized = detail
            .replacingOccurrences(of: " and ", with: ", ")
            .replacingOccurrences(of: "And ", with: ", ")
            .replacingOccurrences(of: "•", with: ", ")

        let parts = normalized
            .split(whereSeparator: { [",", ";", "\n"].contains($0) })
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)) }
            .filter { !$0.isEmpty }

        if parts.isEmpty {
            return []
        }

        if parts.count == 1 {
            return [
                ProcessStepItem(
                    number: 1,
                    title: parts[0],
                    duration: nil,
                    cost: nil,
                    description: nil,
                    actions: [],
                    requirements: [],
                    tips: []
                )
            ]
        }

        return parts.enumerated().map { index, value in
            ProcessStepItem(
                number: index + 1,
                title: value,
                duration: nil,
                cost: nil,
                description: nil,
                actions: [],
                requirements: [],
                tips: []
            )
        }
    }

    private static func fallbackTips(for task: ChecklistTask) -> [TipItem] {
        var tips: [TipItem] = []

        if task.priority == .mustDo {
            tips.append(
                TipItem(
                    text: "Prioritize this task before optional items to avoid early delays.",
                    author: nil,
                    upvotes: nil
                )
            )
        }

        if task.timing != .anytime {
            tips.append(
                TipItem(
                    text: "Complete this \(task.timing.label.lowercased()) so you avoid last-minute issues.",
                    author: nil,
                    upvotes: nil
                )
            )
        }

        if task.sourceURL != nil {
            tips.append(
                TipItem(
                    text: "Use the official source link to verify the latest requirements before submission.",
                    author: nil,
                    upvotes: nil
                )
            )
        }

        return tips
    }

    private static func canonical(_ raw: String) -> String {
        raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
    }

    private static func logIntegrityReport(for categories: [ChecklistCategory], source: String) {
        let categoryIDs = categories.map { canonical($0.id) }
        let uniqueCategoryIDs = Set(categoryIDs)
        let duplicateCategoryCount = max(0, categoryIDs.count - uniqueCategoryIDs.count)
        let emptyCategoryCount = categories.filter { $0.tasks.isEmpty }.count
        let totalTasks = categories.reduce(0) { $0 + $1.tasks.count }

        LaunchMetrics.mark(
            event: "content_integrity_\(source)_c\(categories.count)_t\(totalTasks)_empty\(emptyCategoryCount)_dup\(duplicateCategoryCount)"
        )
    }
}

private nonisolated struct ContentProgressSnapshot: Codable {
    var completedTaskIDs: [String]
    var customTasksByCategory: [String: [ChecklistTask]]
}

struct ContentPayload: Codable {
    let categories: [ChecklistCategory]

    private static let payloadCacheLock = NSLock()
    private static var cachedPayloadByFile: [String: ContentPayload] = [:]

    static func loadFromBundle(named fileName: String) -> ContentPayload? {
        if let cachedPayload = cachedPayload(for: fileName) {
            LaunchMetrics.mark(event: "bundle_content_cache_hit")
            return cachedPayload
        }

        guard let url = Bundle.main.url(forResource: fileName, withExtension: "json") else {
            LaunchMetrics.mark(event: "bundle_content_missing_file")
            CrashReporter.log("bundle content missing file=\(fileName)", level: .error)
            return nil
        }

        let decodeStart = ProcessInfo.processInfo.systemUptime

        guard let data = try? Data(contentsOf: url, options: [.mappedIfSafe]) else {
            LaunchMetrics.mark(event: "bundle_content_read_failed")
            CrashReporter.log("bundle content read failed file=\(fileName)", level: .error)
            return nil
        }

        let decoder = JSONDecoder()
        let payload: ContentPayload
        do {
            payload = try decoder.decode(ContentPayload.self, from: data)
        } catch {
            CrashReporter.record(
                error: error,
                context: "content_decode",
                metadata: ["file": fileName]
            )
            #if DEBUG
            let logger = Logger(
                subsystem: Bundle.main.bundleIdentifier ?? "com.arrivaluk.app",
                category: "startup"
            )
            logger.debug("bundle_content_decode_error file=\(fileName, privacy: .public) error=\(String(describing: error), privacy: .public)")
            #endif

            if let recoveredPayload = decodeLossyPayload(from: data, fileName: fileName) {
                setCachedPayload(recoveredPayload, for: fileName)
                LaunchMetrics.mark(event: "bundle_content_decode_recovered_lossy")
                return recoveredPayload
            }

            LaunchMetrics.mark(event: "bundle_content_decode_failed")
            return nil
        }

        let validation = ContentValidator.validate(payload: payload)
        validation.logSummary(fileName: fileName)
        LaunchMetrics.mark(
            event: "bundle_content_validation_w\(validation.warningCount)_e\(validation.errorCount)"
        )

        #if DEBUG
        if validation.hasErrors {
            LaunchMetrics.mark(event: "bundle_content_validation_failed_debug")
            return nil
        }
        #endif

        setCachedPayload(payload, for: fileName)
        let elapsed = ProcessInfo.processInfo.systemUptime - decodeStart
        LaunchMetrics.mark(event: "bundle_content_decode_success_\(Int(elapsed * 1000))ms")
        return payload
    }

    private static func cachedPayload(for fileName: String) -> ContentPayload? {
        payloadCacheLock.lock()
        defer { payloadCacheLock.unlock() }
        return cachedPayloadByFile[fileName]
    }

    private static func setCachedPayload(_ payload: ContentPayload, for fileName: String) {
        payloadCacheLock.lock()
        cachedPayloadByFile[fileName] = payload
        payloadCacheLock.unlock()
    }

    private static func decodeLossyPayload(from data: Data, fileName: String) -> ContentPayload? {
        guard
            let rootObject = try? JSONSerialization.jsonObject(with: data),
            let rootDict = rootObject as? [String: Any],
            let rawCategories = rootDict["categories"] as? [Any],
            !rawCategories.isEmpty
        else {
            return nil
        }

        let decoder = JSONDecoder()
        var decodedCategories: [ChecklistCategory] = []

        for (categoryIndex, rawCategory) in rawCategories.enumerated() {
            guard JSONSerialization.isValidJSONObject(rawCategory) else { continue }
            guard let categoryData = try? JSONSerialization.data(withJSONObject: rawCategory) else { continue }

            if let category = try? decoder.decode(ChecklistCategory.self, from: categoryData) {
                decodedCategories.append(category)
                continue
            }

            // Fallback: decode category shell and recover valid tasks one by one.
            guard let categoryDict = rawCategory as? [String: Any] else { continue }

            let id = (categoryDict["id"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let title = (categoryDict["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let categoryID = id, !categoryID.isEmpty, let categoryTitle = title, !categoryTitle.isEmpty else {
                continue
            }

            var recoveredTasks: [ChecklistTask] = []
            if let rawTasks = categoryDict["tasks"] as? [Any] {
                for rawTask in rawTasks {
                    guard JSONSerialization.isValidJSONObject(rawTask) else { continue }
                    guard let taskData = try? JSONSerialization.data(withJSONObject: rawTask) else { continue }
                    if let task = try? decoder.decode(ChecklistTask.self, from: taskData) {
                        recoveredTasks.append(task)
                    }
                }
            }

            let recoveredCategory = ChecklistCategory(
                id: categoryID,
                title: categoryTitle,
                subtitle: categoryDict["subtitle"] as? String,
                categoryType: (categoryDict["type"] as? String) ?? (categoryDict["categoryType"] as? String),
                icon: (categoryDict["icon"] as? String) ?? "square.grid.2x2",
                gradient: categoryDict["gradient"] as? [String],
                priority: categoryDict["priority"] as? Int,
                priorityLevel: CategoryPriorityLevel(rawValue: ((categoryDict["priority"] as? String) ?? "").lowercased()) ??
                    CategoryPriorityLevel(rawValue: ((categoryDict["priorityLevel"] as? String) ?? "").lowercased()) ??
                    CategoryPriorityLevel(rawValue: ((categoryDict["visualPriority"] as? String) ?? "").lowercased()),
                urgency: CategoryUrgencyBand(rawValue: ((categoryDict["urgency"] as? String) ?? "").lowercased()),
                accentColorHex: (categoryDict["accentColor"] as? String) ?? (categoryDict["accentColorHex"] as? String),
                deadline: categoryDict["deadline"] as? String,
                isVisibleOverride: categoryDict["isVisible"] as? Bool,
                order: categoryDict["order"] as? Int,
                cityFilters: (categoryDict["cityFilters"] as? [String]) ?? (categoryDict["cities"] as? [String]),
                universityFilters: (categoryDict["universityFilters"] as? [String]) ?? (categoryDict["universities"] as? [String]),
                unlockRequirements: categoryDict["unlockRequirements"] as? String,
                tasks: recoveredTasks
            )
            decodedCategories.append(recoveredCategory)

            #if DEBUG
            let logger = Logger(
                subsystem: Bundle.main.bundleIdentifier ?? "com.arrivaluk.app",
                category: "startup"
            )
            logger.debug("bundle_content_decode_lossy_category file=\(fileName, privacy: .public) index=\(categoryIndex, privacy: .public)")
            #endif
        }

        guard !decodedCategories.isEmpty else { return nil }

        #if DEBUG
        let logger = Logger(
            subsystem: Bundle.main.bundleIdentifier ?? "com.arrivaluk.app",
            category: "startup"
        )
        logger.debug("bundle_content_decode_lossy_success file=\(fileName, privacy: .public) categories=\(decodedCategories.count, privacy: .public)")
        #endif

        return ContentPayload(categories: decodedCategories)
    }
}

enum ContentIssueSeverity: String {
    case warning
    case error
}

struct ContentValidationIssue: Hashable {
    let severity: ContentIssueSeverity
    let path: String
    let message: String
}

struct ContentValidationReport {
    let issues: [ContentValidationIssue]

    var warningCount: Int {
        issues.filter { $0.severity == .warning }.count
    }

    var errorCount: Int {
        issues.filter { $0.severity == .error }.count
    }

    var hasErrors: Bool {
        errorCount > 0
    }

    func logSummary(fileName: String) {
        #if DEBUG
        let logger = Logger(
            subsystem: Bundle.main.bundleIdentifier ?? "com.arrivaluk.app",
            category: "content-validation"
        )

        logger.debug(
            "content_validation file=\(fileName, privacy: .public) warnings=\(self.warningCount) errors=\(self.errorCount)"
        )

        for issue in issues.prefix(120) {
            logger.debug(
                "content_validation_issue severity=\(issue.severity.rawValue, privacy: .public) path=\(issue.path, privacy: .public) message=\(issue.message, privacy: .public)"
            )
        }
        #endif
    }
}

enum ContentValidator {
    static func validate(payload: ContentPayload) -> ContentValidationReport {
        var issues: [ContentValidationIssue] = []

        if payload.categories.isEmpty {
            issues.append(
                ContentValidationIssue(
                    severity: .error,
                    path: "categories",
                    message: "No categories found in payload."
                )
            )
            return ContentValidationReport(issues: issues)
        }

        var seenCategoryIDs: Set<String> = []

        for (categoryIndex, category) in payload.categories.enumerated() {
            let categoryPath = "categories[\(categoryIndex)]"
            validateCategory(
                category,
                path: categoryPath,
                issues: &issues,
                seenCategoryIDs: &seenCategoryIDs
            )
        }

        return ContentValidationReport(issues: issues)
    }

    private static func validateCategory(
        _ category: ChecklistCategory,
        path: String,
        issues: inout [ContentValidationIssue],
        seenCategoryIDs: inout Set<String>
    ) {
        let categoryID = category.id.trimmingCharacters(in: .whitespacesAndNewlines)
        let canonicalCategoryID = canonicalIdentifier(categoryID)
        if categoryID.isEmpty {
            issues.append(issue(.error, path: "\(path).id", message: "Category id is empty."))
        } else if seenCategoryIDs.contains(canonicalCategoryID) {
            issues.append(
                issue(.error, path: "\(path).id", message: "Duplicate category id '\(categoryID)'.")
            )
        } else {
            seenCategoryIDs.insert(canonicalCategoryID)
        }

        if category.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(issue(.error, path: "\(path).title", message: "Category title is empty."))
        }

        if category.icon.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(issue(.warning, path: "\(path).icon", message: "Category icon is empty."))
        }

        if category.tasks.isEmpty {
            issues.append(
                issue(.warning, path: "\(path).tasks", message: "Category has no tasks.")
            )
        }

        if let deadline = category.deadline, !deadline.isEmpty {
            if !isValidDate(deadline) {
                issues.append(
                    issue(
                        .warning,
                        path: "\(path).deadline",
                        message: "Deadline '\(deadline)' is not in ISO-8601 date format (yyyy-MM-dd)."
                    )
                )
            }
        }

        var seenTaskIDs: Set<String> = []
        for (taskIndex, task) in category.tasks.enumerated() {
            validateTask(
                task,
                path: "\(path).tasks[\(taskIndex)]",
                issues: &issues,
                seenTaskIDs: &seenTaskIDs
            )
        }
    }

    private static func validateTask(
        _ task: ChecklistTask,
        path: String,
        issues: inout [ContentValidationIssue],
        seenTaskIDs: inout Set<String>
    ) {
        let taskID = task.id.trimmingCharacters(in: .whitespacesAndNewlines)
        let canonicalTaskID = canonicalIdentifier(taskID)
        if taskID.isEmpty {
            issues.append(issue(.error, path: "\(path).id", message: "Task id is empty."))
        } else if seenTaskIDs.contains(canonicalTaskID) {
            issues.append(issue(.error, path: "\(path).id", message: "Duplicate task id '\(taskID)'."))
        } else {
            seenTaskIDs.insert(canonicalTaskID)
        }

        if task.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(issue(.error, path: "\(path).title", message: "Task title is empty."))
        }

        if let minutes = task.estimatedMinutes, minutes < 0 {
            issues.append(
                issue(.warning, path: "\(path).estimatedMinutes", message: "Estimated minutes is negative.")
            )
        }

        if let sourceURL = task.sourceURL {
            validateURLString(
                sourceURL,
                path: "\(path).sourceURL",
                issues: &issues,
                expectedTrust: nil
            )
        }

        guard let content = task.content else {
            issues.append(
                issue(
                    .warning,
                    path: "\(path).content",
                    message: "Task has no structured content; runtime fallback guidance will be generated."
                )
            )
            return
        }
        validateTaskContent(content, path: "\(path).content", issues: &issues)
    }

    private static func validateTaskContent(
        _ content: TaskContent,
        path: String,
        issues: inout [ContentValidationIssue]
    ) {
        if content.sections.isEmpty {
            issues.append(issue(.warning, path: "\(path).sections", message: "Task content has no sections."))
        }

        for (sectionIndex, section) in content.sections.enumerated() {
            let sectionPath = "\(path).sections[\(sectionIndex)]"

            switch section {
            case .options(let data), .comparisonTable(let data):
                if data.items.isEmpty {
                    issues.append(
                        issue(
                            .warning,
                            path: "\(sectionPath).items",
                            message: "Options section has no items."
                        )
                    )
                }

                for (itemIndex, item) in data.items.enumerated() {
                    let itemPath = "\(sectionPath).items[\(itemIndex)]"
                    if item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        issues.append(issue(.error, path: "\(itemPath).name", message: "Option item name is empty."))
                    }

                    if let link = item.link {
                        validateURLString(
                            link.url,
                            path: "\(itemPath).link.url",
                            issues: &issues,
                            expectedTrust: link.source?.resolvedTrustType
                        )
                        validateSource(link.source, path: "\(itemPath).link.source", issues: &issues)
                    }

                    validateSource(item.source, path: "\(itemPath).source", issues: &issues)
                }
            case .references(let data):
                validateReferences(data.items, path: "\(sectionPath).items", issues: &issues)
            case .officialReferences(let data):
                validateReferences(data.items, path: "\(sectionPath).items", issues: &issues, officialExpected: true)
            case .steps(let data):
                for (stepIndex, step) in data.items.enumerated() {
                    let stepPath = "\(sectionPath).items[\(stepIndex)]"
                    if step.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        issues.append(issue(.error, path: "\(stepPath).title", message: "Step title is empty."))
                    }

                    for (actionIndex, action) in step.actions.enumerated() {
                        let actionPath = "\(stepPath).actions[\(actionIndex)]"
                        if let url = action.url {
                            validateURLString(
                                url,
                                path: "\(actionPath).url",
                                issues: &issues,
                                expectedTrust: action.source?.resolvedTrustType
                            )
                        }
                        validateSource(action.source, path: "\(actionPath).source", issues: &issues)
                    }
                }
            case .apps(let data):
                for (appIndex, app) in data.items.enumerated() {
                    let appPath = "\(sectionPath).items[\(appIndex)]"
                    if app.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        issues.append(issue(.error, path: "\(appPath).name", message: "App name is empty."))
                    }
                    if let ios = app.downloadLinks?.ios {
                        validateURLString(ios, path: "\(appPath).downloadLinks.ios", issues: &issues, expectedTrust: nil)
                    }
                    if let android = app.downloadLinks?.android {
                        validateURLString(android, path: "\(appPath).downloadLinks.android", issues: &issues, expectedTrust: nil)
                    }
                }
            case .why, .overview, .checklist, .tips, .faqs, .unsupported:
                break
            }
        }
    }

    private static func validateReferences(
        _ references: [ReferenceItem],
        path: String,
        issues: inout [ContentValidationIssue],
        officialExpected: Bool = false
    ) {
        for (index, reference) in references.enumerated() {
            let referencePath = "\(path)[\(index)]"
            if reference.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(issue(.error, path: "\(referencePath).title", message: "Reference title is empty."))
            }

            validateURLString(
                reference.url,
                path: "\(referencePath).url",
                issues: &issues,
                expectedTrust: officialExpected ? .official : reference.resolvedSourceMetadata?.resolvedTrustType
            )

            validateSource(reference.resolvedSourceMetadata, path: "\(referencePath).source", issues: &issues)
        }
    }

    private static func validateSource(
        _ source: SourceMetadata?,
        path: String,
        issues: inout [ContentValidationIssue]
    ) {
        guard let source else { return }

        if let verified = source.lastVerified, !verified.isEmpty, !isValidDate(verified) {
            issues.append(
                issue(
                    .warning,
                    path: "\(path).lastVerified",
                    message: "lastVerified '\(verified)' is not in ISO-8601 date format (yyyy-MM-dd)."
                )
            )
        }
    }

    private static func validateURLString(
        _ urlString: String,
        path: String,
        issues: inout [ContentValidationIssue],
        expectedTrust: SourceTrustType?
    ) {
        guard let url = ExternalURLPolicy.normalizedURL(from: urlString) else {
            issues.append(issue(.error, path: path, message: "Invalid URL '\(urlString)'."))
            return
        }

        if expectedTrust == .official || expectedTrust == .university {
            guard let host = url.host?.lowercased() else {
                issues.append(
                    issue(
                        .warning,
                        path: path,
                        message: "Official/university URL is missing host."
                    )
                )
                return
            }

            if !ExternalURLPolicy.isTrustedOfficialOrUniversityHost(host) {
                issues.append(
                    issue(
                        .warning,
                        path: path,
                        message: "Official/university source host '\(host)' is not in the trusted suffix list."
                    )
                )
            }
        }
    }

    private static func isValidDate(_ raw: String) -> Bool {
        if isoDateFormatter.date(from: raw) != nil {
            return true
        }
        return fallbackDateFormatter.date(from: raw) != nil
    }

    private static func issue(
        _ severity: ContentIssueSeverity,
        path: String,
        message: String
    ) -> ContentValidationIssue {
        ContentValidationIssue(severity: severity, path: path, message: message)
    }

    private static func canonicalIdentifier(_ raw: String) -> String {
        raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
    }

    private static let isoDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter
    }()

    private static let fallbackDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

```

## arrival uk/ContentView.swift

```swift
import SwiftUI
import UIKit
import os
import AuthenticationServices
import SafariServices
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif
#if canImport(AppTrackingTransparency)
import AppTrackingTransparency
#endif

struct ContentView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @State private var store = ContentStore.shared
    @State private var adCoordinator = AdCoordinator()
    @State private var profileStore = StudentProfileStore.shared
    @State private var activeWebURL: URL?
    @State private var isProfileSheetPresented = false
    @State private var activeModal: ActiveModal?
    @State private var selectedCategoryIndex: Int?
    @State private var enableDecorativeEffects = false
    @State private var isScrollActive = false
    @State private var scrollIdleWorkItem: DispatchWorkItem?
    @State private var persistProgressTask: Task<Void, Never>?
    @State private var bootstrapWatchdogTask: Task<Void, Never>?
    @State private var homeClock = Date()
    @State private var minuteTickerTask: Task<Void, Never>?
    @State private var isInitialBootstrapInFlight = false
    @State private var hasCompletedInitialBootstrap = false
    @State private var hasLoadedBundleOnce = false
    @Namespace private var categoryHeroNamespace

    init() {
        LaunchMetrics.mark(event: "content_view_init")
    }

    private var prefersConservativeVisuals: Bool {
        PerformanceProfile.prefersConservativeVisuals || store.categories.count >= 18
    }

    private var prefersReducedMotion: Bool {
        reduceMotion || prefersConservativeVisuals
    }

    private var timelinePrimaryMetric: String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let arrivalDay = calendar.startOfDay(for: profileStore.arrivalDate)
        let deltaDays = calendar.dateComponents([.day], from: today, to: arrivalDay).day ?? 0

        if deltaDays > 0 {
            let suffix = deltaDays == 1 ? "day" : "days"
            return "\(deltaDays) \(suffix) until arrival"
        }

        if deltaDays == 0 {
            return "Arrival day in UK"
        }

        let daysSinceArrival = abs(deltaDays)
        return "Day \(daysSinceArrival) in UK"
    }

    private var visibleCategoryIndices: [Int] {
        store.categories.indices
            .filter { index in
                let category = store.categories[index]
                guard category.isVisible else { return false }
                guard !category.tasks.isEmpty else { return false }
                return category.matchesAudience(
                    city: profileStore.city,
                    university: profileStore.selectedUniversity
                )
            }
            .sorted { lhs, rhs in
                let leftCategory = store.categories[lhs]
                let rightCategory = store.categories[rhs]

                if leftCategory.visualPriority.ranking != rightCategory.visualPriority.ranking {
                    return leftCategory.visualPriority.ranking < rightCategory.visualPriority.ranking
                }

                let leftOrder = leftCategory.order ?? .max
                let rightOrder = rightCategory.order ?? .max
                if leftOrder != rightOrder {
                    return leftOrder < rightOrder
                }

                return leftCategory.id < rightCategory.id
            }
    }

    private var selectedCategoryBinding: Binding<ChecklistCategory>? {
        guard let index = selectedCategoryIndex else { return nil }
        guard store.categories.indices.contains(index) else { return nil }
        return $store.categories[index]
    }

    private var selectedCategoryHeroID: String? {
        guard let index = selectedCategoryIndex else { return nil }
        return heroID(for: index)
    }

    private var isCategoryOverlayPresented: Bool {
        selectedCategoryBinding != nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        HeaderView(
                            currentDate: homeClock,
                            arrivalDate: profileStore.arrivalDate,
                            userDisplayName: profileStore.preferredFirstName ?? profileStore.fullName,
                            onSearchTap: {
                                presentSheet(.search)
                            },
                            onProfileTap: {
                                presentSheet(.profileSetup)
                            }
                        )
                        .staggeredEntry(index: 0, isActive: true, prefersReducedMotion: prefersReducedMotion)

                        let orderedIndices = visibleCategoryIndices
                        ForEach(Array(orderedIndices.enumerated()), id: \.element) { position, index in
                            CategoryCard(
                                category: $store.categories[index],
                                allCategories: store.categories,
                                useDecorativeEffects: enableDecorativeEffects,
                                prefersReducedMotion: prefersReducedMotion,
                                heroNamespace: categoryHeroNamespace,
                                heroID: heroID(for: index),
                                isHeroSourceHidden: selectedCategoryIndex == index,
                                suppressShadow: isScrollActive,
                                onOpenCategory: {
                                    openCategory(at: index)
                                }
                            )
                            .staggeredEntry(
                                index: position + 1,
                                isActive: true,
                                prefersReducedMotion: prefersReducedMotion
                            )
                        }

                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 140)
                }
                .refreshable {
                    Haptics.selectionIfAllowed()
                    await refreshHomeContext()
                }
                .zIndex(LayerZIndex.base)
                .opacity(hasCompletedInitialBootstrap ? 1 : 0)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { _ in markScrollActive() }
                        .onEnded { _ in markScrollEnded() }
                )
                .blur(radius: isCategoryOverlayPresented ? 8 : 0)
                .scaleEffect(isCategoryOverlayPresented ? 0.985 : 1, anchor: .top)
                .animation(Motion.heroBackground(prefersReducedMotion: prefersReducedMotion), value: isCategoryOverlayPresented)
                .allowsHitTesting(
                    hasCompletedInitialBootstrap &&
                    !isCategoryOverlayPresented &&
                    activeModal == nil
                )

                if hasCompletedInitialBootstrap &&
                    !isCategoryOverlayPresented &&
                    activeModal == nil {
                    FloatingActionButton {
                        Haptics.selectionIfAllowed()
                        presentSheet(.addTask)
                    }
                    .zIndex(LayerZIndex.stickyHeader)
                }

                if !hasCompletedInitialBootstrap {
                    StartupPlaceholderView(primaryMetric: timelinePrimaryMetric)
                        .transition(.opacity)
                        .zIndex(LayerZIndex.stickyHeader)
                }

                if let selectedCategory = selectedCategoryBinding {
                    CategoryDetailOverlay(
                        category: selectedCategory,
                        allCategories: store.categories,
                        namespace: categoryHeroNamespace,
                        heroID: selectedCategoryHeroID ?? "",
                        prefersReducedMotion: prefersReducedMotion,
                        onClose: closeCategoryDetail,
                        onToggleTask: {
                            registerAdEvent(.taskToggled)
                            Task {
                                await NotificationManager.shared.refreshTaskReminders(
                                    categories: store.categories,
                                    arrivalDate: profileStore.arrivalDate
                                )
                            }
                        },
                        onOpenTask: { task in
                            registerAdEvent(.taskDetailOpened)
                            presentSheet(.taskDetail(task))
                        }
                    )
                    .opacity(activeModal == nil ? 1 : 0)
                    .allowsHitTesting(activeModal == nil)
                    .zIndex(LayerZIndex.categoryOverlay)
                }

                if let activeModal {
                    BottomModalOverlay(
                        maxHeightRatio: modalHeightRatio(for: activeModal),
                        prefersReducedMotion: prefersReducedMotion,
                        onDismiss: dismissActiveModal
                    ) {
                        modalView(for: activeModal)
                    }
                    .zIndex(LayerZIndex.modal)
                }
            }
            .background(
                Theme.background(
                    for: colorScheme,
                    conservative: prefersConservativeVisuals
                )
                .ignoresSafeArea()
            )
            .buttonStyle(AppFastButtonStyle())
            .navigationBarHidden(true)
            .sheet(isPresented: Binding(
                get: { activeWebURL != nil },
                set: { isPresented in
                    if !isPresented {
                        activeWebURL = nil
                    }
                }
            )) {
                if let url = activeWebURL {
                    InAppBrowserSheet(url: url)
                }
            }
            .sheet(isPresented: $isProfileSheetPresented) {
                ProfileSetupSheet(
                    store: profileStore,
                    contentStore: store,
                    onClose: { isProfileSheetPresented = false }
                )
            }
            .environment(\.openURL, OpenURLAction { url in
                handleOpenURL(url)
            })
            .onOpenURL { url in
                if GoogleSignInBridge.handle(url: url) {
                    return
                }

                if ExternalURLPolicy.isAllowed(url) {
                    presentSheet(.web(url))
                } else {
                    let host = url.host ?? "unknown-host"
                    CrashReporter.log("onOpenURL ignored by policy host=\(host)", level: .warning)
                }
            }
            .onChange(of: scenePhase) { _, newValue in
                if newValue == .active {
                    AdRuntime.updateConsentConfiguration()
                    registerAdEvent(.appBecameActive)
                    ensureRenderableState(reason: "scene_active")
                } else if newValue == .inactive || newValue == .background {
                    store.persistProgress()
                    LaunchMetrics.mark(event: "content_progress_flushed_scene_\(scenePhaseLabel(newValue))")
                }
            }
            .onChange(of: store.categories) { _, _ in
                if !hasCompletedInitialBootstrap, !store.categories.isEmpty {
                    hasCompletedInitialBootstrap = true
                    LaunchMetrics.mark(event: "content_unblocked_on_category_change")
                }
                if hasCompletedInitialBootstrap {
                    bootstrapWatchdogTask?.cancel()
                }
                scheduleProgressPersistence()
                Task {
                    await NotificationManager.shared.refreshTaskReminders(
                        categories: store.categories,
                        arrivalDate: profileStore.arrivalDate
                    )
                }
            }
            .onDisappear {
                scrollIdleWorkItem?.cancel()
                persistProgressTask?.cancel()
                bootstrapWatchdogTask?.cancel()
                minuteTickerTask?.cancel()
                minuteTickerTask = nil
            }
            .task {
                await bootstrapInitialViewStateIfNeeded()
                startHomeClockTickerIfNeeded()
                await refreshHomeContext()
            }
        }
    }

    @MainActor
    private func bootstrapInitialViewStateIfNeeded() async {
        guard !isInitialBootstrapInFlight, !hasLoadedBundleOnce else { return }

        isInitialBootstrapInFlight = true
        armBootstrapWatchdogIfNeeded()
        defer { isInitialBootstrapInFlight = false }

        LaunchMetrics.mark(event: "content_view_task_begin")
        CrashReporter.log("content bootstrap started", level: .info)

        // Prime immediately with bundled sample content so first paint never appears blank.
        store.primeWithSampleDataIfNeeded()
        hasCompletedInitialBootstrap = true
        LaunchMetrics.mark(event: "content_unblocked_with_prime_data")

        // Yield once so the placeholder can paint before background loading starts.
        await Task.yield()

        AdRuntime.bootstrapIfNeeded()
        adCoordinator.startSessionIfNeeded()
        profileStore.bootstrapIfNeeded()
        await loadContentIfNeeded()
        await NotificationManager.shared.refreshTaskReminders(
            categories: store.categories,
            arrivalDate: profileStore.arrivalDate
        )

        LaunchMetrics.mark(event: "content_loaded_in_view")
        LaunchMetrics.markStartupBudget(
            milestone: "content_loaded_in_view",
            warningThresholdSeconds: 2.5
        )
        CrashReporter.log("content bootstrap completed categories=\(store.categories.count)", level: .info)
        await enableEffectsAfterFirstFrame()
        ensureRenderableState(reason: "bootstrap_complete")
        presentAdDisclosureIfNeeded()
        bootstrapWatchdogTask?.cancel()
    }

    @MainActor
    private func loadContentIfNeeded() async {
        guard !hasLoadedBundleOnce else { return }
        hasLoadedBundleOnce = true
        await store.loadFromBundle()
        ensureRenderableState(reason: "bundle_load_complete")
    }

    @MainActor
    private func scheduleProgressPersistence() {
        persistProgressTask?.cancel()
        persistProgressTask = Task(priority: .utility) {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                store.persistProgress()
            }
        }
    }

    @MainActor
    private func enableEffectsAfterFirstFrame() async {
        guard !enableDecorativeEffects else { return }

        guard !prefersConservativeVisuals else {
            LaunchMetrics.mark(event: "decorative_effects_skipped_conservative_mode")
            return
        }

        try? await Task.sleep(nanoseconds: 180_000_000)
        enableDecorativeEffects = true
        LaunchMetrics.mark(event: "decorative_effects_enabled")
    }

    @MainActor
    private func registerAdEvent(_ event: AdEvent) {
        if let opportunity = adCoordinator.register(event: event) {
            AdRuntime.requestAd(for: opportunity)
        }
    }

    @MainActor
    private func markScrollActive() {
        scrollIdleWorkItem?.cancel()
        if isScrollActive { return }
        withAnimation(.linear(duration: 0.08)) {
            isScrollActive = true
        }
    }

    @MainActor
    private func markScrollEnded() {
        scrollIdleWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            withAnimation(.easeOut(duration: 0.20)) {
                isScrollActive = false
            }
        }
        scrollIdleWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: workItem)
    }

    @MainActor
    private func presentSheet(_ sheet: ActiveSheet) {
        switch sheet {
        case .web(let url):
            activeWebURL = url
        case .search:
            activeModal = .search
        case .addTask:
            activeModal = .addTask
        case .adPrivacy:
            activeModal = .adPrivacy
        case .taskDetail(let task):
            activeModal = .taskDetail(task)
        case .profileSetup:
            isProfileSheetPresented = true
        }
    }

    @MainActor
    private func dismissActiveModal() {
        withAnimation(Motion.modalDismiss(prefersReducedMotion: prefersReducedMotion)) {
            activeModal = nil
        }
    }

    @MainActor
    private func openCategory(at index: Int) {
        guard store.categories.indices.contains(index) else {
            LaunchMetrics.mark(event: "open_category_blocked_missing_category")
            return
        }
        let category = store.categories[index]
        guard !category.tasks.isEmpty else {
            LaunchMetrics.mark(event: "open_category_blocked_empty_tasks_\(category.id)")
            return
        }
        guard !isCategoryOverlayPresented else { return }
        Haptics.softImpactIfAllowed()
        withAnimation(Motion.heroExpand(prefersReducedMotion: prefersReducedMotion)) {
            selectedCategoryIndex = index
        }
    }

    @MainActor
    private func closeCategoryDetail() {
        withAnimation(Motion.heroCollapse(prefersReducedMotion: prefersReducedMotion)) {
            selectedCategoryIndex = nil
        }
    }

    @MainActor
    private func ensureRenderableState(reason: String) {
        if store.categories.isEmpty {
            store.primeWithSampleDataIfNeeded()
            LaunchMetrics.mark(event: "render_state_recovered_prime_\(reason)")
        }

        if !hasCompletedInitialBootstrap && !store.categories.isEmpty {
            hasCompletedInitialBootstrap = true
            LaunchMetrics.mark(event: "render_state_recovered_unblock_\(reason)")
        }
    }

    @MainActor
    private func armBootstrapWatchdogIfNeeded() {
        bootstrapWatchdogTask?.cancel()
        bootstrapWatchdogTask = Task(priority: .utility) {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard !hasCompletedInitialBootstrap else { return }
                store.primeWithSampleDataIfNeeded()
                hasCompletedInitialBootstrap = true
                LaunchMetrics.mark(event: "bootstrap_watchdog_forced_unblock")
                CrashReporter.log("bootstrap watchdog forced fallback content", level: .warning)
            }
        }
    }

    @MainActor
    private func presentAdDisclosureIfNeeded() {
        guard AdPreferencesStore.shared.needsInitialDisclosure else { return }
        guard activeModal == nil else { return }
        guard !isCategoryOverlayPresented else { return }

        withAnimation(Motion.modalAppear(prefersReducedMotion: prefersReducedMotion)) {
            activeModal = .adPrivacy
        }
    }

    @MainActor
    private func startHomeClockTickerIfNeeded() {
        guard minuteTickerTask == nil else { return }

        minuteTickerTask = Task(priority: .utility) {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60_000_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    homeClock = Date()
                }
            }
        }
    }

    @MainActor
    private func refreshHomeContext() async {
        homeClock = Date()
    }

    private func heroID(for index: Int) -> String {
        guard store.categories.indices.contains(index) else {
            return "category-invalid-\(index)"
        }

        let category = store.categories[index]
        let orderSegment = category.order.map(String.init) ?? "na"
        return "category-\(index)-\(category.id)-\(orderSegment)"
    }

    private func scenePhaseLabel(_ phase: ScenePhase) -> String {
        switch phase {
        case .active:
            return "active"
        case .inactive:
            return "inactive"
        case .background:
            return "background"
        @unknown default:
            return "unknown"
        }
    }

    private func modalHeightRatio(for modal: ActiveModal) -> CGFloat {
        switch modal {
        case .search:
            return 0.86
        case .addTask:
            return 0.78
        case .adPrivacy:
            return 0.70
        case .help:
            return 0.65
        case .emergencyContacts:
            return 0.78
        case .privacyInfo:
            return 0.70
        case .taskDetail:
            return 0.90
        }
    }

    @ViewBuilder
    private func modalView(for modal: ActiveModal) -> some View {
        switch modal {
        case .search:
            TaskSearchSheet(
                categories: store.categories,
                city: profileStore.city,
                university: profileStore.selectedUniversity,
                onSelectTask: { task in
                    withAnimation(Motion.modalAppear(prefersReducedMotion: prefersReducedMotion)) {
                        activeModal = .taskDetail(task)
                    }
                },
                onClose: dismissActiveModal
            )
        case .addTask:
            AddTaskSheet(
                categories: $store.categories,
                onTaskAdded: {
                    registerAdEvent(.personalTaskAdded)
                },
                onClose: dismissActiveModal
            )
        case .adPrivacy:
            AdPrivacySheet(preferences: AdPreferencesStore.shared, onClose: dismissActiveModal)
        case .help:
            HelpSheet(
                onOpenAdPrivacy: {
                    withAnimation(Motion.modalAppear(prefersReducedMotion: prefersReducedMotion)) {
                        activeModal = .adPrivacy
                    }
                },
                onOpenEmergencyContacts: {
                    withAnimation(Motion.modalAppear(prefersReducedMotion: prefersReducedMotion)) {
                        activeModal = .emergencyContacts
                    }
                },
                onOpenPrivacy: {
                    withAnimation(Motion.modalAppear(prefersReducedMotion: prefersReducedMotion)) {
                        activeModal = .privacyInfo
                    }
                },
                onClose: dismissActiveModal
            )
        case .emergencyContacts:
            EmergencyContactsSheet(onClose: dismissActiveModal)
        case .privacyInfo:
            PrivacyInfoSheet(onClose: dismissActiveModal)
        case .taskDetail(let task):
            TaskDetailSheet(task: task, onClose: dismissActiveModal)
        }
    }

    private enum ActiveModal: Identifiable {
        case search
        case addTask
        case adPrivacy
        case help
        case emergencyContacts
        case privacyInfo
        case taskDetail(ChecklistTask)

        var id: String {
            switch self {
            case .search:
                return "search"
            case .addTask:
                return "add-task"
            case .adPrivacy:
                return "ad-privacy"
            case .help:
                return "help"
            case .emergencyContacts:
                return "emergency-contacts"
            case .privacyInfo:
                return "privacy-info"
            case .taskDetail(let task):
                return "task-\(task.id)"
            }
        }
    }

    private enum ActiveSheet: Identifiable {
        case search
        case addTask
        case adPrivacy
        case taskDetail(ChecklistTask)
        case profileSetup
        case web(URL)

        var id: String {
            switch self {
            case .search:
                return "search"
            case .addTask:
                return "add-task"
            case .adPrivacy:
                return "ad-privacy"
            case .taskDetail(let task):
                return "task-\(task.id)"
            case .profileSetup:
                return "profile-setup"
            case .web(let url):
                return "web-\(url.absoluteString)"
            }
        }
    }

    @MainActor
    private func handleOpenURL(_ url: URL) -> OpenURLAction.Result {
        if GoogleSignInBridge.handle(url: url) {
            return .handled
        }

        guard ExternalURLPolicy.isAllowed(url) else {
            let host = url.host ?? "unknown-host"
            let scheme = url.scheme ?? "unknown-scheme"
            CrashReporter.log("blocked external URL scheme=\(scheme) host=\(host)", level: .warning)
            return .systemAction
        }
        registerAdEvent(.resourceOpened)
        Motion.mutate {
            activeWebURL = url
        }
        return .handled
    }
}

private struct InAppBrowserSheet: View {
    let url: URL

    var body: some View {
        InAppBrowserView(url: url)
            .ignoresSafeArea()
    }
}

private struct InAppBrowserView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let configuration = SFSafariViewController.Configuration()
        configuration.entersReaderIfAvailable = false
        configuration.barCollapsingEnabled = true
        return SFSafariViewController(url: url, configuration: configuration)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

struct GoogleSignInIdentity {
    let userID: String
    let email: String
    let fullName: String?
}

private enum GoogleSignInBridgeError: LocalizedError {
    case sdkNotLinked
    case missingClientID
    case missingReversedClientID
    case missingURLScheme(String)
    case missingPresenter
    case missingEmail
    case cancelled

    var errorDescription: String? {
        switch self {
        case .sdkNotLinked:
            return "Google Sign-In SDK is not linked in this build."
        case .missingClientID:
            return "Google client ID is missing. Add GoogleService-Info.plist first."
        case .missingReversedClientID:
            return "Google reversed client ID is missing. Ensure GoogleService-Info.plist contains REVERSED_CLIENT_ID."
        case .missingURLScheme(let scheme):
            return "Missing URL scheme '\(scheme)' in app Info settings. Add it to URL Types so Google can return to the app."
        case .missingPresenter:
            return "Could not find an active screen to present Google Sign-In."
        case .missingEmail:
            return "Google account did not return an email."
        case .cancelled:
            return "Google Sign-In was cancelled."
        }
    }
}

@MainActor
private enum GoogleSignInBridge {
    static var isSDKLinked: Bool {
        #if canImport(GoogleSignIn)
        return true
        #else
        return false
        #endif
    }

    static func handle(url: URL) -> Bool {
        #if canImport(GoogleSignIn)
        return GIDSignIn.sharedInstance.handle(url)
        #else
        return false
        #endif
    }

    static func signOut() {
        #if canImport(GoogleSignIn)
        GIDSignIn.sharedInstance.signOut()
        #endif
    }

    static func signIn(presenting: UIViewController?) async throws -> GoogleSignInIdentity {
        #if canImport(GoogleSignIn)
        guard let presenting else {
            throw GoogleSignInBridgeError.missingPresenter
        }

        guard let clientID = readClientID() else {
            throw GoogleSignInBridgeError.missingClientID
        }
        guard let reversedClientID = readReversedClientID() else {
            throw GoogleSignInBridgeError.missingReversedClientID
        }
        guard hasURLScheme(reversedClientID) else {
            throw GoogleSignInBridgeError.missingURLScheme(reversedClientID)
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenting)
            guard let email = result.user.profile?.email else {
                throw GoogleSignInBridgeError.missingEmail
            }

            return GoogleSignInIdentity(
                userID: result.user.userID ?? email.lowercased(),
                email: email.lowercased(),
                fullName: result.user.profile?.name
            )
        } catch {
            let nsError = error as NSError
            if nsError.domain == "com.google.GIDSignIn", nsError.code == -5 {
                throw GoogleSignInBridgeError.cancelled
            }
            throw error
        }
        #else
        throw GoogleSignInBridgeError.sdkNotLinked
        #endif
    }

    private static func readClientID() -> String? {
        if let infoClientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String,
           !infoClientID.isEmpty {
            return infoClientID
        }

        guard
            let plistPath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
            let plist = NSDictionary(contentsOfFile: plistPath),
            let clientID = plist["CLIENT_ID"] as? String,
            !clientID.isEmpty
        else {
            return nil
        }

        return clientID
    }

    private static func readReversedClientID() -> String? {
        if
            let urlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]],
            !urlTypes.isEmpty
        {
            for entry in urlTypes {
                if let schemes = entry["CFBundleURLSchemes"] as? [String] {
                    for scheme in schemes where !scheme.isEmpty {
                        if scheme.contains("com.googleusercontent.apps.") {
                            return scheme
                        }
                    }
                }
            }
        }

        guard
            let plistPath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
            let plist = NSDictionary(contentsOfFile: plistPath),
            let reversed = plist["REVERSED_CLIENT_ID"] as? String,
            !reversed.isEmpty
        else {
            return nil
        }

        return reversed
    }

    private static func hasURLScheme(_ expectedScheme: String) -> Bool {
        guard let urlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] else {
            return false
        }

        for entry in urlTypes {
            guard let schemes = entry["CFBundleURLSchemes"] as? [String] else { continue }
            for scheme in schemes where scheme.caseInsensitiveCompare(expectedScheme) == .orderedSame {
                return true
            }
        }

        return false
    }
}

@MainActor
private enum PresentationAnchor {
    static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let activeScene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        guard
            let window = activeScene?.windows.first(where: \.isKeyWindow),
            let root = window.rootViewController
        else {
            return nil
        }

        return topMostViewController(from: root)
    }

    private static func topMostViewController(from root: UIViewController) -> UIViewController {
        if let presented = root.presentedViewController {
            return topMostViewController(from: presented)
        }

        if let navigation = root as? UINavigationController,
           let visible = navigation.visibleViewController {
            return topMostViewController(from: visible)
        }

        if let tabBar = root as? UITabBarController,
           let selected = tabBar.selectedViewController {
            return topMostViewController(from: selected)
        }

        return root
    }
}

enum CategoryPriorityLevel: String, Codable, CaseIterable, Hashable {
    case critical
    case high
    case medium
    case low

    var ranking: Int {
        switch self {
        case .critical:
            return 0
        case .high:
            return 1
        case .medium:
            return 2
        case .low:
            return 3
        }
    }

    static func fromLegacy(priority: Int) -> CategoryPriorityLevel {
        switch priority {
        case ..<2:
            return .critical
        case 2:
            return .high
        case 3:
            return .medium
        default:
            return .low
        }
    }
}

enum CategoryUrgencyBand: String, Codable, Hashable {
    case immediate
    case week1
    case week2
    case anytime
    case completed

    var ranking: Int {
        switch self {
        case .immediate:
            return 0
        case .week1:
            return 1
        case .week2:
            return 2
        case .anytime:
            return 3
        case .completed:
            return 4
        }
    }
}

private enum CategoryAccentStyle: Hashable {
    case gradient
    case solidBorder
    case tintedBackground
    case icon
}

private enum CategoryShadowLevel: Hashable {
    case none
    case subtle
    case medium
    case elevated
}

private struct CategoryVisualStyle: Hashable {
    let minHeight: CGFloat
    let cornerRadius: CGFloat
    let titleFontSize: CGFloat
    let titleWeight: Font.Weight
    let titleTracking: CGFloat
    let subtitleFontSize: CGFloat
    let subtitleWeight: Font.Weight
    let subtitleOpacity: Double
    let metaFontSize: CGFloat
    let iconSize: CGFloat
    let borderWidth: CGFloat
    let accentStyle: CategoryAccentStyle
    let shadowLevel: CategoryShadowLevel
    let cardPadding: CGFloat
}

private enum CategoryVisualHierarchy {
    private static let styles: [CategoryPriorityLevel: CategoryVisualStyle] = [
        .critical: CategoryVisualStyle(
            minHeight: 120,
            cornerRadius: 20,
            titleFontSize: 20,
            titleWeight: .bold,
            titleTracking: -0.2,
            subtitleFontSize: 13,
            subtitleWeight: .regular,
            subtitleOpacity: 0.82,
            metaFontSize: 13,
            iconSize: 56,
            borderWidth: 0,
            accentStyle: .gradient,
            shadowLevel: .elevated,
            cardPadding: 16
        ),
        .high: CategoryVisualStyle(
            minHeight: 120,
            cornerRadius: 20,
            titleFontSize: 20,
            titleWeight: .bold,
            titleTracking: -0.2,
            subtitleFontSize: 13,
            subtitleWeight: .regular,
            subtitleOpacity: 0.82,
            metaFontSize: 13,
            iconSize: 56,
            borderWidth: 0,
            accentStyle: .solidBorder,
            shadowLevel: .medium,
            cardPadding: 16
        ),
        .medium: CategoryVisualStyle(
            minHeight: 120,
            cornerRadius: 20,
            titleFontSize: 20,
            titleWeight: .semibold,
            titleTracking: -0.1,
            subtitleFontSize: 13,
            subtitleWeight: .regular,
            subtitleOpacity: 0.82,
            metaFontSize: 13,
            iconSize: 56,
            borderWidth: 0,
            accentStyle: .tintedBackground,
            shadowLevel: .medium,
            cardPadding: 16
        ),
        .low: CategoryVisualStyle(
            minHeight: 120,
            cornerRadius: 20,
            titleFontSize: 18,
            titleWeight: .semibold,
            titleTracking: -0.1,
            subtitleFontSize: 13,
            subtitleWeight: .regular,
            subtitleOpacity: 0.82,
            metaFontSize: 13,
            iconSize: 56,
            borderWidth: 0,
            accentStyle: .icon,
            shadowLevel: .subtle,
            cardPadding: 16
        )
    ]

    static func getVisualStyle(_ priority: CategoryPriorityLevel) -> CategoryVisualStyle {
        if let resolved = styles[priority] {
            return resolved
        }
        if let fallback = styles[.medium] {
            return fallback
        }
        return CategoryVisualStyle(
            minHeight: 140,
            cornerRadius: 22,
            titleFontSize: 20,
            titleWeight: .semibold,
            titleTracking: 0,
            subtitleFontSize: 12,
            subtitleWeight: .regular,
            subtitleOpacity: 0.78,
            metaFontSize: 12,
            iconSize: 42,
            borderWidth: 0,
            accentStyle: .tintedBackground,
            shadowLevel: .medium,
            cardPadding: 18
        )
    }
}

private struct StartupPlaceholderView: View {
    let primaryMetric: String

    var body: some View {
        VStack(spacing: Theme.spaceL) {
            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: Theme.spaceXS) {
                Text("Arrival UK")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(1)

                Text(primaryMetric)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.spaceL)

            ProgressView("Loading your checklist…")
                .progressViewStyle(.circular)
                .font(.system(size: 14, weight: .medium))
                .tint(Theme.brandPrimary)
                .foregroundStyle(Theme.secondaryText)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.spaceL)
        .padding(.vertical, Theme.spaceL)
    }
}

private struct HeaderView: View {
    let currentDate: Date
    let arrivalDate: Date
    let userDisplayName: String
    let onSearchTap: () -> Void
    let onProfileTap: () -> Void

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: currentDate)
        if hour < 12 { return "Good morning" }
        if hour < 18 { return "Good afternoon" }
        return "Good evening"
    }

    private var dateBadgeText: String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: currentDate)
    }

    private var greetingLine: String {
        "\(greetingText), \(userFirstName)"
    }

    private var userFirstName: String {
        let trimmed = userDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Alex" }
        return trimmed.components(separatedBy: .whitespaces).first ?? trimmed
    }

    private var dateContextLine: String {
        if daysUntilArrival == 0 {
            return "\(dateBadgeText) • Landing day"
        }
        if daysUntilArrival > 0 {
            if daysUntilArrival == 1 {
                return "\(dateBadgeText) • Landing tomorrow"
            }
            return "\(dateBadgeText) • \(daysUntilArrival) days to landing"
        }
        let elapsed = abs(daysUntilArrival)
        return "\(dateBadgeText) • Day \(elapsed) in UK"
    }

    private var profileInitial: String {
        let trimmed = userDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return "U" }
        return String(first).uppercased()
    }

    private var daysUntilArrival: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: currentDate)
        let arrival = calendar.startOfDay(for: arrivalDate)
        return calendar.dateComponents([.day], from: today, to: arrival).day ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spaceM) {
            HStack(alignment: .top, spacing: Theme.spaceM) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("ARRIVAL UK")
                        .font(.system(size: 38, weight: .heavy))
                        .foregroundStyle(Theme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)

                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(Theme.brandPrimary)
                        .frame(width: 40, height: 3)
                        .padding(.top, 2)
                        .padding(.bottom, 4)

                    Text(greetingLine)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.primaryText)
                        .lineLimit(1)
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)

                    Text(dateContextLine)
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.90)
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)

                    Text("Your journey to UK starts here")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(Theme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.90)
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                }

                Spacer(minLength: Theme.spaceS)

                HStack(alignment: .center, spacing: 12) {
                    Button(action: onSearchTap) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.primaryText)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(Theme.card)
                                    .overlay(
                                        Circle()
                                            .stroke(Theme.stroke, lineWidth: 1)
                                    )
                            )
                            .shadow(color: Theme.shadowSoft, radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(AppFastButtonStyle())
                    .accessibilityLabel("Search tasks")

                    Button(action: onProfileTap) {
                        Text(profileInitial)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Theme.inverseText)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(Theme.navy900)
                                    .overlay(
                                        Circle()
                                            .stroke(Theme.luxuryGoldBorder, lineWidth: 1.5)
                                    )
                            )
                            .shadow(color: Theme.shadowMedium, radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(AppFastButtonStyle())
                    .accessibilityLabel("Open profile")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.spaceL)
        .padding(.vertical, Theme.spaceM)
        .background(
            ZStack {
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.95),
                        Theme.backgroundPrimary.opacity(0.90)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .blur(radius: 20)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous)
                .stroke(Color.white.opacity(0.30), lineWidth: 1)
                .blur(radius: 0.5)
        )
        .shadow(color: Theme.shadowSoft, radius: 14, x: 0, y: 6)
    }
}

private struct PressFeedbackButtonStyle: ButtonStyle {
    let prefersReducedMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(
                configuration.isPressed
                    ? Motion.pressDown(prefersReducedMotion: prefersReducedMotion)
                    : Motion.pressUp(prefersReducedMotion: prefersReducedMotion),
                value: configuration.isPressed
            )
    }
}

private struct AppFastButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var prefersReducedMotion: Bool {
        reduceMotion || PerformanceProfile.prefersConservativeVisuals
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(
                configuration.isPressed
                    ? Motion.pressDown(prefersReducedMotion: prefersReducedMotion)
                    : Motion.pressUp(prefersReducedMotion: prefersReducedMotion),
                value: configuration.isPressed
            )
    }
}

private struct SkeuomorphicCategoryIcon: View {
    let categoryID: String
    let symbolName: String
    let size: CGFloat

    private var style: SkeuomorphicIconStyle {
        SkeuomorphicIconStyle.style(for: categoryID, fallbackSymbol: symbolName)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [style.start, style.end],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.34), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .padding(1)

            Image(systemName: style.symbol)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.95))
                .shadow(color: Color.black.opacity(0.25), radius: 1.5, x: 0, y: 1)
        }
        .frame(width: size, height: size)
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .stroke(Color.white.opacity(0.36), lineWidth: 1)
        )
        .shadow(color: style.end.opacity(0.35), radius: 6, x: 0, y: 4)
        .accessibilityHidden(true)
    }
}

private struct SkeuomorphicIconStyle {
    let symbol: String
    let start: Color
    let end: Color

    static func style(for rawID: String, fallbackSymbol: String) -> SkeuomorphicIconStyle {
        let id = rawID
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")

        switch id {
        case "before_arrival", "getting_settled":
            return SkeuomorphicIconStyle(symbol: "airplane.departure", start: Color(hex: "#7B9FD3"), end: Color(hex: "#5A7FB8"))
        case "academic_setup":
            return SkeuomorphicIconStyle(symbol: "graduationcap.fill", start: Color(hex: "#E85D9A"), end: Color(hex: "#C74780"))
        case "health_admin", "admin_legal":
            return SkeuomorphicIconStyle(symbol: "cross.case.fill", start: Color(hex: "#EF7474"), end: Color(hex: "#DC5252"))
        case "money_banking", "daily_living":
            return SkeuomorphicIconStyle(symbol: "sterlingsign.circle.fill", start: Color(hex: "#FFB74D"), end: Color(hex: "#FFA726"))
        case "housing", "housing_accommodation":
            return SkeuomorphicIconStyle(symbol: "house.fill", start: Color(hex: "#74B9FF"), end: Color(hex: "#0984E3"))
        case "work_career":
            return SkeuomorphicIconStyle(symbol: "briefcase.fill", start: Color(hex: "#9B59B6"), end: Color(hex: "#8E44AD"))
        case "travel_transport", "travel_discounts", "travel":
            return SkeuomorphicIconStyle(symbol: "tram.fill", start: Color(hex: "#00B894"), end: Color(hex: "#00A383"))
        case "legal_docs", "legal_documentation":
            return SkeuomorphicIconStyle(symbol: "scale.3d", start: Color(hex: "#A29BFE"), end: Color(hex: "#6C5CE7"))
        case "shopping_essentials":
            return SkeuomorphicIconStyle(symbol: "bag.fill", start: Color(hex: "#FD79A8"), end: Color(hex: "#E84393"))
        case "communication_setup":
            return SkeuomorphicIconStyle(symbol: "iphone", start: Color(hex: "#55EFC4"), end: Color(hex: "#00CEC9"))
        case "insurance_safety":
            return SkeuomorphicIconStyle(symbol: "shield.fill", start: Color(hex: "#81C784"), end: Color(hex: "#66BB6A"))
        case "student_discounts":
            return SkeuomorphicIconStyle(symbol: "creditcard.fill", start: Color(hex: "#F093FB"), end: Color(hex: "#F5576C"))
        case "internet_tech":
            return SkeuomorphicIconStyle(symbol: "wifi", start: Color(hex: "#A8E6CF"), end: Color(hex: "#3DDC84"))
        case "social_networking", "social_community":
            return SkeuomorphicIconStyle(symbol: "person.3.fill", start: Color(hex: "#FFB88C"), end: Color(hex: "#DE6262"))
        case "student_life":
            return SkeuomorphicIconStyle(symbol: "backpack.fill", start: Color(hex: "#FFA07A"), end: Color(hex: "#FA8072"))
        default:
            return SkeuomorphicIconStyle(symbol: fallbackSymbol, start: Theme.brandPrimary, end: Theme.brandSecondary)
        }
    }
}

private extension Color {
    init(hex: String) {
        let cleaned = hex.replacingOccurrences(of: "#", with: "")
        let value = UInt64(cleaned, radix: 16) ?? 0
        let red = Double((value & 0xFF0000) >> 16) / 255.0
        let green = Double((value & 0x00FF00) >> 8) / 255.0
        let blue = Double(value & 0x0000FF) / 255.0
        self = Color(red: red, green: green, blue: blue)
    }
}

private struct FloatingActionButton: View {
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var isPressed = false
    @State private var iconRotation: Double = 0

    private let accentStart = Color(uiColor: UIColor(red: 0.93, green: 0.49, blue: 0.30, alpha: 1))
    private let accentEnd = Color(uiColor: UIColor(red: 0.91, green: 0.36, blue: 0.25, alpha: 1))

    var body: some View {
        VStack {
            Spacer(minLength: 0)
            Button {
                if !reduceMotion {
                    withAnimation(.easeInOut(duration: 0.12)) {
                        iconRotation = 90
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                        withAnimation(.easeInOut(duration: 0.12)) {
                            iconRotation = 0
                        }
                    }
                }
                action()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .bold))
                        .rotationEffect(.degrees(iconRotation))

                    Text("Add Task")
                        .font(.system(size: 17, weight: .bold))
                }
                .foregroundStyle(Theme.inverseText)
                .padding(.horizontal, 28)
                .padding(.vertical, 16)
                .background(
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [accentStart, accentEnd],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
            }
            .buttonStyle(.plain)
            .scaleEffect(isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.20, dampingFraction: 0.70), value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .updating($isPressed) { _, state, _ in
                        state = true
                    }
            )
            .shadow(color: accentStart.opacity(0.40), radius: 16, x: 0, y: 8)
            .accessibilityLabel("Add task")
            .padding(.bottom, 32)
        }
        .padding(.horizontal, 20)
    }
}

private struct CategoryCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding var category: ChecklistCategory
    let allCategories: [ChecklistCategory]
    let useDecorativeEffects: Bool
    let prefersReducedMotion: Bool
    let heroNamespace: Namespace.ID
    let heroID: String
    let isHeroSourceHidden: Bool
    let suppressShadow: Bool
    let onOpenCategory: () -> Void
    @State private var iconScale: CGFloat = 0.90
    @State private var iconRotation: Double = -3

    private var stats: CategoryStats {
        CategoryStats(tasks: category.tasks)
    }

    private var visualStyle: CategoryVisualStyle {
        CategoryVisualHierarchy.getVisualStyle(category.visualPriority)
    }

    private var palette: CategoryPalette {
        Theme.palette(for: category, among: allCategories)
    }

    private var subtitleLine: String {
        category.resolvedSubtitle
    }

    private var metaLine: String {
        "\(stats.completedCount)/\(stats.totalCount) tasks"
    }

    private var beforeArrivalMetaLine: String {
        "\(stats.completedCount) of \(stats.totalCount) tasks"
    }

    private var normalizedCategoryID: String {
        category.id
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
    }

    private var isBeforeArrivalHeroCard: Bool {
        normalizedCategoryID == "before_arrival"
    }

    private var beforeArrivalBadgeText: String {
        stats.progress >= 1 ? "DONE" : "URGENT"
    }

    private var beforeArrivalBadgeBackground: Color {
        stats.progress >= 1 ? Theme.successMain : Color(hex: "#EF4444")
    }

    private var cardShadowColor: Color {
        palette.shadowColor.opacity(useDecorativeEffects ? 0.30 : 0.22)
    }

    private var usesAccessibilityLayout: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    private var cardHeight: CGFloat {
        usesAccessibilityLayout ? max(132, visualStyle.minHeight) : visualStyle.minHeight
    }

    private var beforeArrivalCardHeight: CGFloat {
        usesAccessibilityLayout ? 240 : 208
    }

    private var titleLineLimit: Int {
        usesAccessibilityLayout ? 2 : 1
    }

    private var subtitleLineLimit: Int {
        usesAccessibilityLayout ? 2 : 1
    }

    private var metaLineLimit: Int {
        usesAccessibilityLayout ? 2 : 1
    }

    private var urgencyBadgeLabel: String {
        switch category.urgencyBand {
        case .immediate:
            return "NOW"
        case .week1:
            return "WEEK 1"
        case .week2:
            return "WEEK 2"
        case .anytime:
            return "ANYTIME"
        case .completed:
            return "DONE"
        }
    }

    var body: some View {
        Button(action: onOpenCategory) {
            Group {
                if isBeforeArrivalHeroCard {
                    VStack(spacing: 0) {
                        Capsule(style: .continuous)
                            .fill(Theme.luxuryGold.opacity(0.40))
                            .frame(width: 84, height: 2)
                            .padding(.top, 8)

                        SkeuomorphicCategoryIcon(
                            categoryID: category.id,
                            symbolName: category.icon,
                            size: 80
                        )
                        .scaleEffect(iconScale)
                        .rotationEffect(.degrees(iconRotation))
                        .matchedGeometryEffect(id: "category-icon-\(heroID)", in: heroNamespace)
                        .padding(.top, 24)

                        Text(category.title.uppercased())
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.97))
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .matchedGeometryEffect(id: "category-title-\(heroID)", in: heroNamespace)
                            .padding(.top, 12)

                        Text(subtitleLine)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(Color.white.opacity(0.78))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .padding(.top, 8)
                            .padding(.horizontal, 20)

                        Text(beforeArrivalMetaLine)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.95))
                            .monospacedDigit()
                            .lineLimit(1)
                            .padding(.top, 4)

                        Text(beforeArrivalBadgeText)
                            .font(.system(size: 12, weight: .bold))
                            .tracking(0.6)
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(beforeArrivalBadgeBackground)
                            )
                            .padding(.top, 16)

                        Capsule(style: .continuous)
                            .fill(Theme.luxuryGold.opacity(0.40))
                            .frame(width: 84, height: 2)
                            .padding(.top, 14)
                            .padding(.bottom, 16)
                    }
                    .frame(maxWidth: .infinity, minHeight: beforeArrivalCardHeight)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(hex: "#6366F1"),
                                        Color(hex: "#8B5CF6"),
                                        Color(hex: "#A855F7")
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .opacity(0.18)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous)
                            .stroke(Color.white.opacity(0.24), lineWidth: 1)
                    )
                    .matchedGeometryEffect(id: "category-card-\(heroID)", in: heroNamespace)
                    .shadow(
                        color: suppressShadow ? .clear : Color(hex: "#9333EA").opacity(0.22),
                        radius: 32,
                        x: 0,
                        y: 12
                    )
                    .contentShape(RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous))
                } else {
                    VStack(spacing: Theme.spaceS) {
                        HStack(alignment: .top, spacing: Theme.spaceS) {
                            SkeuomorphicCategoryIcon(
                                categoryID: category.id,
                                symbolName: category.icon,
                                size: visualStyle.iconSize
                            )
                            .scaleEffect(iconScale)
                            .rotationEffect(.degrees(iconRotation))
                            .matchedGeometryEffect(id: "category-icon-\(heroID)", in: heroNamespace)

                            Spacer(minLength: Theme.spaceS)

                            Text(urgencyBadgeLabel)
                                .font(.system(size: 11, weight: .bold))
                                .tracking(0.5)
                                .foregroundStyle(Theme.categoryBadgeText(for: category, among: allCategories))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(Theme.categoryBadgeBackground(for: category, among: allCategories))
                                )
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(category.title)
                                .font(.system(size: visualStyle.titleFontSize, weight: visualStyle.titleWeight))
                                .foregroundStyle(Color.white.opacity(0.95))
                                .lineLimit(titleLineLimit)
                                .minimumScaleFactor(0.90)
                                .matchedGeometryEffect(id: "category-title-\(heroID)", in: heroNamespace)
                                .dynamicTypeSize(.xSmall ... .accessibility2)
                                .fixedSize(horizontal: false, vertical: true)

                            Text(subtitleLine)
                                .font(.system(size: visualStyle.subtitleFontSize, weight: visualStyle.subtitleWeight))
                                .foregroundStyle(Color.white.opacity(visualStyle.subtitleOpacity))
                                .lineLimit(subtitleLineLimit)
                                .dynamicTypeSize(.xSmall ... .accessibility2)
                                .fixedSize(horizontal: false, vertical: true)

                            Text(metaLine)
                                .font(.system(size: visualStyle.metaFontSize, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.86))
                                .lineLimit(metaLineLimit)
                                .dynamicTypeSize(.xSmall ... .accessibility2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: cardHeight, alignment: .topLeading)
                    .padding(visualStyle.cardPadding)
                    .background(
                        RoundedRectangle(cornerRadius: visualStyle.cornerRadius, style: .continuous)
                            .fill(palette.linearGradient)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: visualStyle.cornerRadius, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .opacity(0.32)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: visualStyle.cornerRadius, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.60), Color.white.opacity(0.20)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .matchedGeometryEffect(id: "category-card-\(heroID)", in: heroNamespace)
                    .shadow(
                        color: suppressShadow ? .clear : cardShadowColor,
                        radius: 15,
                        x: 0,
                        y: 8
                    )
                    .contentShape(RoundedRectangle(cornerRadius: visualStyle.cornerRadius, style: .continuous))
                }
            }
        }
        .buttonStyle(PressFeedbackButtonStyle(prefersReducedMotion: prefersReducedMotion))
        .opacity(isHeroSourceHidden ? 0 : 1)
        .onAppear {
            if prefersReducedMotion {
                iconScale = 1
                iconRotation = 0
            } else {
                iconScale = 0.90
                iconRotation = -3
                withAnimation(.spring(response: 0.35, dampingFraction: 0.72).delay(0.05)) {
                    iconScale = 1
                }
                withAnimation(.spring(response: 0.42, dampingFraction: 0.74).delay(0.08)) {
                    iconRotation = 0
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            isBeforeArrivalHeroCard
            ? "\(category.title). \(beforeArrivalBadgeText). \(beforeArrivalMetaLine) remaining."
            : "\(category.title). \(urgencyBadgeLabel). \(stats.completedCount) of \(stats.totalCount) tasks completed."
        )
        .accessibilityHint("Double tap to view tasks")
    }
}

private struct CategoryDetailOverlay: View {
    @Binding var category: ChecklistCategory
    let allCategories: [ChecklistCategory]
    let namespace: Namespace.ID
    let heroID: String
    let prefersReducedMotion: Bool
    let onClose: () -> Void
    let onToggleTask: () -> Void
    let onOpenTask: (ChecklistTask) -> Void

    private var cardTextColor: Color {
        Theme.categoryText(for: category, among: allCategories)
    }

    private var visualStyle: CategoryVisualStyle {
        CategoryVisualHierarchy.getVisualStyle(category.visualPriority)
    }

    private var stats: CategoryStats {
        CategoryStats(tasks: category.tasks)
    }

    private var urgencyLabel: String {
        switch category.urgencyBand {
        case .immediate:
            return "NOW"
        case .week1:
            return "WEEK 1"
        case .week2:
            return "WEEK 2"
        case .anytime:
            return "ANYTIME"
        case .completed:
            return "DONE"
        }
    }

    private var taskCountSummary: String {
        guard stats.totalCount > 0 else { return "No tasks yet" }
        let taskWord = stats.totalCount == 1 ? "task" : "tasks"
        return "\(stats.completedCount)/\(stats.totalCount) \(taskWord)"
    }

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                HStack {
                    Button {
                        onClose()
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.primaryText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Theme.card)
                            )
                    }
                    .buttonStyle(AppFastButtonStyle())

                    Spacer()
                }
                .padding(.horizontal, Theme.spaceXL)
                .padding(.top, Theme.spaceL)
                .padding(.bottom, Theme.spaceS)

                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.spaceM) {
                        VStack(alignment: .leading, spacing: Theme.spaceS) {
                            HStack(alignment: .top, spacing: Theme.spaceS) {
                                SkeuomorphicCategoryIcon(
                                    categoryID: category.id,
                                    symbolName: category.icon,
                                    size: visualStyle.iconSize,
                                )
                                .matchedGeometryEffect(id: "category-icon-\(heroID)", in: namespace)

                                Spacer()

                                Text(urgencyLabel)
                                    .font(.system(size: 10, weight: .semibold))
                                    .tracking(0.6)
                                    .foregroundStyle(Theme.categoryBadgeText(for: category, among: allCategories))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(
                                        Capsule(style: .continuous)
                                            .fill(Theme.categoryBadgeBackground(for: category, among: allCategories))
                                    )
                            }

                            Text(category.title)
                                .font(.system(size: visualStyle.titleFontSize, weight: visualStyle.titleWeight))
                                .foregroundStyle(cardTextColor)
                                .lineLimit(2)
                                .matchedGeometryEffect(id: "category-title-\(heroID)", in: namespace)

                            HStack(spacing: Theme.spaceS) {
                                Text(taskCountSummary)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(cardTextColor.opacity(0.86))

                                ProgressView(value: stats.progress)
                                    .progressViewStyle(.linear)
                                    .tint(Theme.successMain)

                                Text("\(Int((stats.progress * 100).rounded()))%")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Theme.successMain)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: 160, alignment: .topLeading)
                        .padding(Theme.spaceXL)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous)
                                .fill(Theme.palette(for: category, among: allCategories).linearGradient)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous)
                                .fill(.ultraThinMaterial)
                                .opacity(0.30)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous)
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.60), Color.white.opacity(0.20)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                        .matchedGeometryEffect(id: "category-card-\(heroID)", in: namespace)

                        VStack(alignment: .leading, spacing: Theme.spaceS) {
                            Text("Tasks")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Theme.primaryText)

                            if category.tasks.isEmpty {
                                Text("No tasks available yet.")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Theme.secondaryText)
                                    .padding(.vertical, Theme.spaceS)
                            } else {
                                ForEach($category.tasks) { $task in
                                    TaskRow(
                                        task: $task,
                                        onToggleComplete: onToggleTask,
                                        onOpenDetails: {
                                            onOpenTask(task)
                                        }
                                    )
                                }
                            }
                        }
                        .padding(.bottom, Theme.bottomBarReserve)
                    }
                    .padding(.horizontal, Theme.spaceXL)
                    .padding(.bottom, Theme.spaceM)
                }
            }
            .background(Theme.cream200.ignoresSafeArea())
        }
    }
}

private struct BottomModalOverlay<Content: View>: View {
    let maxHeightRatio: CGFloat
    let prefersReducedMotion: Bool
    let onDismiss: () -> Void
    @ViewBuilder let content: Content

    @GestureState private var dragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let safeRatio = min(max(maxHeightRatio, 0.45), 0.95)
            let sheetHeight = min(proxy.size.height * safeRatio, 760)
            let bottomInset = max(proxy.safeAreaInsets.bottom, Theme.spaceS)
            let dismissDragGesture = DragGesture(minimumDistance: 3)
                .updating($dragOffset) { value, state, _ in
                    if value.translation.height > 0 {
                        state = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height > 140 {
                        onDismiss()
                    }
                }

            ZStack(alignment: .bottom) {
                ModalBackdrop(onDismiss: onDismiss)
                    .zIndex(0)
                    .allowsHitTesting(true)

                VStack(spacing: 0) {
                    Capsule(style: .continuous)
                        .fill(Theme.strokeStrong)
                        .frame(width: 36, height: 5)
                        .padding(.top, Theme.spaceS)
                        .padding(.bottom, Theme.spaceXS)
                        .padding(.horizontal, Theme.spaceXL)
                        .contentShape(Rectangle())
                        .gesture(dismissDragGesture)
                        .accessibilityHidden(true)

                    content
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
                .frame(maxWidth: .infinity)
                .frame(height: sheetHeight, alignment: .top)
                .background(
                    RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous)
                        .fill(Theme.card)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous)
                        .stroke(Theme.stroke, lineWidth: 1)
                )
                .clipShape(
                    RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous)
                )
                .shadow(color: Theme.shadowElevated, radius: 16, x: 0, y: -2)
                .offset(y: max(0, dragOffset))
                .padding(.horizontal, Theme.spaceM)
                .padding(.bottom, bottomInset)
                .zIndex(1)
                .allowsHitTesting(true)
            }
        }
        .transition(
            .asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .move(edge: .bottom).combined(with: .opacity)
            )
        )
        .zIndex(LayerZIndex.modal)
    }
}

private struct ModalBackdrop: View {
    let onDismiss: () -> Void

    var body: some View {
        Rectangle()
            .fill(Theme.modalScrim)
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture {
                onDismiss()
            }
    }
}

private struct TaskRow: View {
    @Binding var task: ChecklistTask
    let onToggleComplete: () -> Void
    let onOpenDetails: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    task.isComplete.toggle()
                }
                onToggleComplete()
                if task.isComplete {
                    Haptics.successIfAllowed()
                } else {
                    Haptics.selectionIfAllowed()
                }
            } label: {
                CheckMark(isOn: task.isComplete)
            }
            .buttonStyle(AppFastButtonStyle())

            Button(action: onOpenDetails) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(task.title)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(task.isComplete ? Theme.tertiaryText : Theme.primaryText)
                            .strikethrough(task.isComplete, color: Theme.tertiaryText.opacity(0.65))

                        if let detail = task.detail, !detail.isEmpty {
                            Text(detail)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(Theme.secondaryText)
                                .lineLimit(2)
                        }

                        Text("\(task.priority.label) • \(task.timing.label)")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.tertiaryText)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.tertiaryText)
                        .padding(.top, 2)
                }
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(AppFastButtonStyle())
            .accessibilityLabel(task.title)
            .accessibilityHint("Opens task details")
            .accessibilityAddTraits(.isButton)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Theme.stroke.opacity(0.8), lineWidth: 1)
        )
        .shadow(color: Theme.shadowSoft, radius: 2, x: 0, y: 1)
        .accessibilityElement(children: .contain)
    }
}

private struct TaskMetaBadge: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(Theme.secondaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(Theme.track)
            )
    }
}

private struct TaskMetaBadgeWrap: View {
    let labels: [String]

    private let columns = [
        GridItem(.adaptive(minimum: 120), spacing: 8, alignment: .leading)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(Array(labels.enumerated()), id: \.offset) { _, label in
                TaskMetaBadge(title: label)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private struct TaskDetailSheet: View {
    @Environment(\.openURL) private var openURL

    let task: ChecklistTask
    var onClose: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Theme.spaceS) {
                Text("Task Details")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.primaryText)

                Spacer()

                Button {
                    close()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.secondaryText)
                        .frame(width: 30, height: 30)
                        .background(
                            Circle()
                                .fill(Theme.track)
                        )
                }
                .buttonStyle(AppFastButtonStyle())
            }
            .padding(.horizontal, Theme.spaceXL)
            .padding(.top, Theme.spaceM)
            .padding(.bottom, Theme.spaceS)
            .background(Theme.card)

            Divider()
                .overlay(Theme.stroke)

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spaceM) {
                    Text(task.title)
                        .font(.system(.title2, weight: .semibold))
                        .foregroundStyle(Theme.primaryText)
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .layoutPriority(2)

                    TaskMetaBadgeWrap(labels: badgeLabels)

                    if let content = task.content, !content.sections.isEmpty {
                        TaskContentRenderer(sections: content.sections)
                    } else {
                        if !fallbackSteps.isEmpty {
                            TaskSectionCard(title: "Steps", icon: "list.number") {
                                VStack(alignment: .leading, spacing: Theme.spaceS) {
                                    ForEach(Array(fallbackSteps.enumerated()), id: \.offset) { index, step in
                                        HStack(alignment: .top, spacing: 10) {
                                            Text("\(index + 1)")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundStyle(Theme.primaryText)
                                                .frame(width: 24, height: 24)
                                                .background(
                                                    Circle()
                                                        .fill(Theme.track)
                                                )

                                            Text(step)
                                                .font(.body)
                                                .foregroundStyle(Theme.secondaryText)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                    }
                                }
                            }
                        }

                        if !fallbackTips.isEmpty {
                            TaskSectionCard(title: "Tips", icon: "sparkles") {
                                VStack(alignment: .leading, spacing: Theme.spaceS) {
                                    ForEach(Array(fallbackTips.enumerated()), id: \.offset) { _, tip in
                                        HStack(alignment: .top, spacing: 8) {
                                            Image(systemName: "checkmark.seal.fill")
                                                .font(.system(size: 13))
                                                .foregroundStyle(Theme.successDark)
                                                .padding(.top, 2)
                                            Text(tip)
                                                .font(.body)
                                                .foregroundStyle(Theme.secondaryText)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                    }
                                }
                            }
                        }

                        if let sourceTitle = task.sourceTitle, !sourceTitle.isEmpty {
                            Text("Source")
                                .font(.headline)
                                .foregroundStyle(Theme.primaryText)
                                .padding(.top, 6)

                            if let sourceURL = task.sourceURL,
                               let url = ExternalURLPolicy.normalizedURL(from: sourceURL) {
                                Button {
                                    openURL(url)
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "arrow.up.right.square")
                                            .foregroundStyle(Theme.inverseText)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Open Official Guidance")
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundStyle(Theme.inverseText)
                                            Text(sourceTitle)
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundStyle(Theme.inverseText.opacity(0.86))
                                                .lineLimit(2)
                                                .multilineTextAlignment(.leading)
                                        }

                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(Theme.inverseText.opacity(0.9))
                                    }
                                    .padding(12)
                                    .frame(maxWidth: .infinity)
                                    .frame(minHeight: 52, alignment: .leading)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(Theme.primaryButtonBackground)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(Theme.terracotta700.opacity(0.55), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(AppFastButtonStyle())
                            } else {
                                Text(sourceTitle)
                                    .font(.body)
                                    .foregroundStyle(Theme.secondaryText)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Theme.card)

            Divider()
                .overlay(Theme.stroke)

            HStack {
                Spacer()
                Button("Done") {
                    close()
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.inverseText)
                .padding(.horizontal, Theme.spaceXL)
                .padding(.vertical, 10)
                .background(
                    Capsule(style: .continuous)
                        .fill(Theme.primaryButtonBackground)
                )
                .buttonStyle(AppFastButtonStyle())
            }
            .padding(.horizontal, Theme.spaceXL)
            .padding(.vertical, Theme.spaceM)
            .background(Theme.card)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.card)
    }

    private var badgeLabels: [String] {
        var labels: [String] = [
            task.priority.label,
            task.timing.label,
            task.urgency.label
        ]
        if let estimatedMinutes = task.estimatedMinutes, estimatedMinutes > 0 {
            labels.insert("\(estimatedMinutes) min", at: 2)
        }
        return labels
    }

    private var fallbackSteps: [String] {
        guard let detail = task.detail?.trimmingCharacters(in: .whitespacesAndNewlines), !detail.isEmpty else {
            return []
        }

        let normalized = detail
            .replacingOccurrences(of: " and ", with: ", ")
            .replacingOccurrences(of: "And ", with: ", ")
            .replacingOccurrences(of: "•", with: ",")

        let parts = normalized
            .split(whereSeparator: { [",", ";", "\n"].contains($0) })
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)) }
            .filter { !$0.isEmpty }

        if parts.count <= 1 {
            return [detail]
        }

        return parts
    }

    private var fallbackTips: [String] {
        var tips: [String] = []

        if task.timing != .anytime {
            tips.append("Complete this \(task.timing.label.lowercased()) so you avoid last-minute delays.")
        }

        if task.sourceURL != nil {
            tips.append("Use the official source link below to confirm the latest requirement updates.")
        }

        return tips
    }

    private func close() {
        onClose?()
    }
}

private struct TaskContentRenderer: View {
    let sections: [ContentSection]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spaceM) {
            ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                sectionView(section)
            }
        }
    }

    @ViewBuilder
    private func sectionView(_ section: ContentSection) -> some View {
        switch section {
        case .why(let value):
            TaskSectionCard(title: value.title ?? "Why this matters", icon: value.icon ?? "lightbulb.fill") {
                Text(value.content)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        case .overview(let value):
            TaskSectionCard(title: value.title ?? "Overview", icon: "text.alignleft") {
                Text(value.content)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        case .checklist(let value):
            TaskSectionCard(title: value.title ?? "Checklist", icon: "checklist") {
                VStack(alignment: .leading, spacing: Theme.spaceXS) {
                    ForEach(value.items, id: \.self) { item in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Theme.accent)
                                .font(.system(size: 14))
                                .padding(.top, 2)
                            Text(item)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        case .options(let value):
            TaskOptionsSectionView(title: value.title ?? "Options", options: value.items)
        case .comparisonTable(let value):
            TaskOptionsSectionView(title: value.title ?? "Comparison", options: value.items)
        case .tips(let value):
            TaskSectionCard(title: value.title ?? "Tips", icon: "sparkles") {
                VStack(alignment: .leading, spacing: Theme.spaceS) {
                    ForEach(Array(value.items.enumerated()), id: \.offset) { _, item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\"\(item.text)\"")
                                .font(.body)
                                .foregroundStyle(.secondary)
                            if let author = item.author, !author.isEmpty {
                                Text(author)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }
        case .references(let value):
            TaskReferencesSectionView(title: value.title ?? "References", items: value.items)
        case .officialReferences(let value):
            TaskReferencesSectionView(title: value.title ?? "Official resources", items: value.items)
        case .steps(let value):
            TaskStepsSectionView(title: value.title ?? "Step-by-step", steps: value.items)
        case .apps(let value):
            TaskAppsSectionView(title: value.title ?? "Helpful apps", items: value.items)
        case .faqs(let value):
            TaskFAQSectionView(title: value.title ?? "Common questions", items: value.items)
        case .unsupported(let value):
            TaskUnsupportedSectionView(section: value)
        }
    }
}

private struct TaskSectionCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spaceS) {
            HStack(spacing: 8) {
                if UIImage(systemName: icon) != nil {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                } else {
                    Text(icon)
                }

                Text(title)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(.primary)
            }

            content
        }
        .padding(Theme.spaceM)
        .cardChrome(elevated: false)
    }
}

private struct SourceMetadataLine: View {
    let source: SourceMetadata

    private var tone: Color {
        Theme.sourceTint(for: source.resolvedTrustType)
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(source.resolvedTrustType.label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(tone)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule(style: .continuous)
                        .fill(tone.opacity(0.12))
                )

            if let sourceName = source.sourceName, !sourceName.isEmpty {
                Text(sourceName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if let verifiedLabel = source.verifiedLabel {
                Text("Verified \(verifiedLabel)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

private struct TaskOptionsSectionView: View {
    let title: String
    let options: [OptionItem]

    var body: some View {
        TaskSectionCard(title: title, icon: "tablecells") {
            VStack(alignment: .leading, spacing: Theme.spaceS) {
                ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                    VStack(alignment: .leading, spacing: Theme.spaceXS) {
                        HStack {
                            Text(option.name)
                                .font(.system(.body, weight: .semibold))
                            Spacer()
                            if let price = option.priceLevel {
                                Text(price)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if let description = option.description, !description.isEmpty {
                            Text(description)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        if let rating = option.rating {
                            Text("Rating: \(String(format: "%.1f", rating))/5")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if let source = option.source ?? option.link?.source {
                            SourceMetadataLine(source: source)
                        }

                        if !option.highlights.isEmpty {
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(option.highlights, id: \.self) { highlight in
                                    Text("• \(highlight)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        HStack(spacing: Theme.spaceXS) {
                            if let linkURL = option.link?.resolvedURL {
                                Link(destination: linkURL) {
                                    Label(option.link?.label ?? "Open Link", systemImage: "arrow.up.right.square")
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 8)
                                        .background(
                                            Capsule(style: .continuous)
                                                .fill(Theme.track)
                                        )
                                }
                                .buttonStyle(AppFastButtonStyle())
                            }

                            if let mapsURL = option.location?.mapsURL {
                                Link(destination: mapsURL) {
                                    Label("Find Nearby", systemImage: "location")
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 8)
                                        .background(
                                            Capsule(style: .continuous)
                                                .fill(Theme.track)
                                        )
                                }
                                .buttonStyle(AppFastButtonStyle())
                            }
                        }
                    }
                    .padding(Theme.spaceS)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous)
                            .fill(Theme.track.opacity(0.6))
                    )
                }
            }
        }
    }
}

private struct TaskReferencesSectionView: View {
    let title: String
    let items: [ReferenceItem]

    var body: some View {
        TaskSectionCard(title: title, icon: "link") {
            VStack(alignment: .leading, spacing: Theme.spaceS) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    if let url = ExternalURLPolicy.normalizedURL(from: item.url) {
                        Link(destination: url) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.up.right.square")
                                    .font(.system(size: 12, weight: .semibold))
                                Text(item.title)
                                    .font(.footnote.weight(.semibold))
                                Spacer()
                            }
                            .foregroundStyle(.primary)
                        }
                        .buttonStyle(AppFastButtonStyle())
                    }

                    if let description = item.description, !description.isEmpty {
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let source = item.resolvedSourceMetadata {
                        SourceMetadataLine(source: source)
                    }
                }
            }
        }
    }
}

private struct TaskStepsSectionView: View {
    let title: String
    let steps: [ProcessStepItem]

    var body: some View {
        TaskSectionCard(title: title, icon: "list.number") {
            VStack(alignment: .leading, spacing: Theme.spaceS) {
                ForEach(Array(steps.enumerated()), id: \.offset) { _, step in
                    VStack(alignment: .leading, spacing: Theme.spaceXS) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("\(step.number).")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Theme.accent)
                            Text(step.title)
                                .font(.footnote.weight(.semibold))
                        }

                        if let description = step.description, !description.isEmpty {
                            Text(description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if !step.requirements.isEmpty {
                            ForEach(step.requirements, id: \.self) { requirement in
                                Text("• \(requirement)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if !step.actions.isEmpty {
                            HStack(spacing: Theme.spaceXS) {
                                ForEach(Array(step.actions.enumerated()), id: \.offset) { _, action in
                                    if let actionURL = action.resolvedURL, ExternalURLPolicy.isAllowed(actionURL) {
                                        Link(destination: actionURL) {
                                            Text(action.label)
                                                .font(.caption2.weight(.semibold))
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 6)
                                                .background(
                                                    Capsule(style: .continuous)
                                                        .fill(Theme.track)
                                                )
                                        }
                                        .buttonStyle(AppFastButtonStyle())
                                    }
                                }
                            }
                        }
                    }
                    .padding(Theme.spaceS)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous)
                            .fill(Theme.track.opacity(0.55))
                    )
                }
            }
        }
    }
}

private struct TaskAppsSectionView: View {
    let title: String
    let items: [AppRecommendationItem]

    var body: some View {
        TaskSectionCard(title: title, icon: "square.and.arrow.down") {
            VStack(alignment: .leading, spacing: Theme.spaceS) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(.footnote.weight(.semibold))
                            if let description = item.description, !description.isEmpty {
                                Text(description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if let targetURL = item.downloadLinks?.primaryURL {
                            Link("Open", destination: targetURL)
                                .font(.caption.weight(.semibold))
                        }
                    }
                }
            }
        }
    }
}

private struct TaskFAQSectionView: View {
    let title: String
    let items: [FAQItem]

    var body: some View {
        TaskSectionCard(title: title, icon: "questionmark.circle") {
            VStack(alignment: .leading, spacing: Theme.spaceXS) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    DisclosureGroup(item.question) {
                        Text(item.answer)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)
                    }
                    .font(.footnote.weight(.semibold))
                }
            }
        }
    }
}

private struct TaskUnsupportedSectionView: View {
    let section: UnsupportedSectionData

    var body: some View {
        TaskSectionCard(title: section.title ?? "More information", icon: "info.circle") {
            VStack(alignment: .leading, spacing: Theme.spaceS) {
                Text("Section type: \(section.type)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                if let payload = section.payload {
                    TaskJSONValueView(value: payload)
                } else {
                    Text("No additional content available.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct TaskJSONValueView: View {
    let value: JSONValue

    var body: some View {
        switch value {
        case .object(let dictionary):
            VStack(alignment: .leading, spacing: Theme.spaceXS) {
                ForEach(dictionary.keys.sorted(), id: \.self) { key in
                    if let payload = dictionary[key] {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(key.humanReadableJSONKey)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            TaskJSONValueView(value: payload)
                                .padding(.leading, Theme.spaceXS)
                        }
                    }
                }
            }
        case .array(let array):
            VStack(alignment: .leading, spacing: Theme.spaceXS) {
                ForEach(Array(array.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 6) {
                        Text("•")
                            .foregroundStyle(.secondary)
                        TaskJSONValueView(value: item)
                    }
                }
            }
        case .string(let stringValue):
            Text(stringValue)
                .font(.footnote)
                .foregroundStyle(.secondary)
        case .number(let numberValue):
            Text(numberValue.formatted())
                .font(.footnote)
                .foregroundStyle(.secondary)
        case .bool(let boolValue):
            Text(boolValue ? "Yes" : "No")
                .font(.footnote)
                .foregroundStyle(.secondary)
        case .null:
            Text("None")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
    }
}

private extension String {
    var humanReadableJSONKey: String {
        self
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
    }
}

private struct CheckMark: View {
    let isOn: Bool

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(isOn ? Theme.successMain : Theme.strokeStrong, lineWidth: 2)
                .background(
                    Circle()
                        .fill(isOn ? Theme.successMain : Color.clear)
                )

            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.white)
                .opacity(isOn ? 1 : 0)
                .scaleEffect(isOn ? 1 : 0.6)
        }
        .frame(width: 24, height: 24)
        .animation(.spring(response: 0.24, dampingFraction: 0.7), value: isOn)
    }
}

private struct AddTaskSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var categories: [ChecklistCategory]
    let onTaskAdded: () -> Void
    var onClose: (() -> Void)? = nil

    @State private var title: String = ""
    @State private var detail: String = ""
    @State private var selectedCategoryID: String

    init(
        categories: Binding<[ChecklistCategory]>,
        onTaskAdded: @escaping () -> Void = {},
        onClose: (() -> Void)? = nil
    ) {
        self._categories = categories
        self.onTaskAdded = onTaskAdded
        self.onClose = onClose
        self._selectedCategoryID = State(
            initialValue: categories.wrappedValue.first?.id ?? ""
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("Task title", text: $title)
                    TextField("Short note (optional)", text: $detail)
                }

                Section("Category") {
                    Picker("Category", selection: $selectedCategoryID) {
                        ForEach(categories) { category in
                            Text(category.title).tag(category.id)
                        }
                    }
                }
            }
            .navigationTitle("Add Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { close() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addTask() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func addTask() {
        guard let index = categories.firstIndex(where: { $0.id == selectedCategoryID }) else {
            close()
            return
        }

        let newTask = ChecklistTask(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            detail: detail.trimmingCharacters(in: .whitespacesAndNewlines),
            isComplete: false,
            isCustom: true
        )

        Motion.mutate {
            categories[index].tasks.append(newTask)
        }
        onTaskAdded()
        close()
    }

    private func close() {
        onClose?()
        dismiss()
    }
}

private struct ProfileSetupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    let store: StudentProfileStore
    let contentStore: ContentStore
    var onClose: (() -> Void)? = nil

    @State private var fullName: String
    @State private var googleEmailInput: String
    @State private var selectedUniversity: String
    @State private var customUniversity: String
    @State private var courseName: String
    @State private var city: String
    @State private var studyLevel: StudyLevel
    @State private var arrivalDate: Date
    @State private var showGoogleInfo = false
    @State private var showGoogleSignInError = false
    @State private var googleSignInErrorMessage = ""
    @State private var isGoogleSignInInFlight = false
    @State private var showSwitchProviderAlert = false
    @State private var showSignOutAlert = false
    @State private var pendingProviderSwitch: StudentAuthProvider = .none

    init(store: StudentProfileStore, contentStore: ContentStore, onClose: (() -> Void)? = nil) {
        self.store = store
        self.contentStore = contentStore
        self.onClose = onClose
        self._fullName = State(initialValue: store.fullName)
        self._googleEmailInput = State(initialValue: store.email)
        self._courseName = State(initialValue: store.courseName)
        self._city = State(initialValue: store.city)
        self._studyLevel = State(initialValue: store.studyLevel)
        self._arrivalDate = State(initialValue: store.arrivalDate)

        if UniversityCatalog.popularUK.contains(store.selectedUniversity) {
            self._selectedUniversity = State(initialValue: store.selectedUniversity)
            self._customUniversity = State(initialValue: "")
        } else if !store.selectedUniversity.isEmpty {
            self._selectedUniversity = State(initialValue: "Other")
            self._customUniversity = State(initialValue: store.selectedUniversity)
        } else {
            self._selectedUniversity = State(initialValue: UniversityCatalog.popularUK.first ?? "Other")
            self._customUniversity = State(initialValue: "")
        }
    }

    private var resolvedUniversity: String {
        if selectedUniversity == "Other" {
            return customUniversity.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return selectedUniversity
    }

    private var normalizedName: String {
        fullName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedGoogleEmail: String {
        googleEmailInput.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var requiresGoogleEmail: Bool {
        store.authProvider == .google
    }

    private var isGoogleEmailValid: Bool {
        let candidate = normalizedGoogleEmail
        guard !candidate.isEmpty else { return false }
        let parts = candidate.split(separator: "@")
        guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else { return false }
        return parts[1].contains(".")
    }

    private var canSave: Bool {
        guard !normalizedName.isEmpty && !resolvedUniversity.isEmpty else { return false }
        if requiresGoogleEmail {
            return isGoogleEmailValid
        }
        return true
    }

    private var googleStatusLabel: String {
        guard store.authProvider == .google else { return "Email mode" }
        return store.googleUserID == nil ? "Email mode" : "Connected"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Login") {
                    SignInWithAppleButton(
                        .signIn,
                        onRequest: { request in
                            request.requestedScopes = [.fullName, .email]
                        },
                        onCompletion: handleAppleSignIn
                    )
                    .signInWithAppleButtonStyle(
                        colorScheme == .dark ? .white : .black
                    )
                    .frame(height: 44)

                    if store.authProvider == .apple {
                        Label("Signed in with Apple", systemImage: "checkmark.seal.fill")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        Task { await handleGoogleTap() }
                    } label: {
                        HStack {
                            Image(systemName: "globe")
                            Text(isGoogleSignInInFlight ? "Connecting Google..." : "Continue with Google")
                            Spacer()
                            Text(googleStatusLabel)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(AppFastButtonStyle())
                    .disabled(isGoogleSignInInFlight)

                    if store.authProvider == .google || !googleEmailInput.isEmpty {
                        TextField("Google email", text: $googleEmailInput)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)

                        if !normalizedGoogleEmail.isEmpty && !isGoogleEmailValid {
                            Text("Enter a valid email address")
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    }

                    if store.authProvider != .none {
                        Button("Sign out", role: .destructive) {
                            showSignOutAlert = true
                        }
                    }

                    Text("Current login: \(store.authProvider.label)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Student Details") {
                    TextField("Full name", text: $fullName)

                    Picker("University", selection: $selectedUniversity) {
                        ForEach(UniversityCatalog.popularUK, id: \.self) { university in
                            Text(university).tag(university)
                        }
                        Text("Other").tag("Other")
                    }

                    if selectedUniversity == "Other" {
                        TextField("Enter university name", text: $customUniversity)
                    }

                    TextField("Course", text: $courseName)
                    TextField("City", text: $city)

                    Picker("Study level", selection: $studyLevel) {
                        ForEach(StudyLevel.allCases, id: \.self) { level in
                            Text(level.label).tag(level)
                        }
                    }

                    DatePicker("Arrival date", selection: $arrivalDate, displayedComponents: .date)
                }
            }
            .navigationTitle("Student Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { close() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveProfile() }
                        .disabled(!canSave)
                }
            }
            .alert("Google Sign-In Setup", isPresented: $showGoogleInfo) {
                Button("Use Email Mode") {
                    store.setGoogleMode()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Google Sign-In SDK is not linked or configured. Add GoogleService-Info.plist and GoogleSignIn package, then this button will open Google account login.")
            }
            .alert("Google Sign-In Failed", isPresented: $showGoogleSignInError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(googleSignInErrorMessage)
            }
            .alert("Switch Login Provider?", isPresented: $showSwitchProviderAlert) {
                Button("Switch") {
                    if pendingProviderSwitch == .google {
                        Task { await beginGoogleSignIn() }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Switching providers signs out the current account for this device. Your profile data stays saved.")
            }
            .alert("Sign out?", isPresented: $showSignOutAlert) {
                Button("Sign Out", role: .destructive) {
                    GoogleSignInBridge.signOut()
                    store.secureSignOut(contentStore: .shared)
                    NotificationManager.shared.cancelAllReminders()
                    googleEmailInput = ""
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You can sign in again anytime.")
            }
        }
    }

    private func handleGoogleTap() async {
        if store.authProvider == .apple {
            pendingProviderSwitch = .google
            showSwitchProviderAlert = true
            return
        }
        await beginGoogleSignIn()
    }

    @MainActor
    private func beginGoogleSignIn() async {
        if !GoogleSignInBridge.isSDKLinked {
            showGoogleInfo = true
            return
        }

        isGoogleSignInInFlight = true
        defer { isGoogleSignInInFlight = false }

        do {
            let identity = try await GoogleSignInBridge.signIn(
                presenting: PresentationAnchor.topViewController()
            )
            store.applyGoogleIdentity(identity)
            googleEmailInput = identity.email

            if normalizedName.isEmpty, let fullName = identity.fullName, !fullName.isEmpty {
                self.fullName = fullName
            }
        } catch GoogleSignInBridgeError.cancelled {
            return
        } catch let knownError as GoogleSignInBridgeError {
            CrashReporter.record(
                error: knownError,
                context: "google_sign_in",
                metadata: ["error": String(describing: knownError)]
            )
            googleSignInErrorMessage = knownError.errorDescription ?? "Google Sign-In failed."
            showGoogleSignInError = true
        } catch {
            CrashReporter.record(
                error: error,
                context: "google_sign_in",
                metadata: ["phase": "unexpected"]
            )
            googleSignInErrorMessage = error.localizedDescription
            showGoogleSignInError = true
        }
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, any Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                return
            }

            store.applyAppleCredential(credential)

            if normalizedName.isEmpty, !store.fullName.isEmpty {
                fullName = store.fullName
            }
        case .failure(let error):
            CrashReporter.record(
                error: error,
                context: "apple_sign_in",
                metadata: ["provider": "apple"]
            )
            break
        }
    }

    private func saveProfile() {
        if store.authProvider == .google {
            store.setGoogleIdentity(email: normalizedGoogleEmail)
        }

        store.updateProfile(
            fullName: normalizedName,
            selectedUniversity: resolvedUniversity,
            courseName: courseName,
            city: city,
            studyLevel: studyLevel,
            arrivalDate: arrivalDate
        )

        Task {
            let allowed = await NotificationManager.shared.requestPermissionIfNeeded(
                promptIfUndetermined: true
            )
            guard allowed else { return }
            await NotificationManager.shared.refreshTaskReminders(
                categories: contentStore.categories,
                arrivalDate: arrivalDate
            )
        }

        close()
    }

    private func close() {
        onClose?()
        dismiss()
    }
}

private struct AdPrivacySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var preferences: AdPreferencesStore
    var onClose: (() -> Void)? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section("Ad Experience") {
                    Text("Ads are delayed by warm-up and interaction rules to avoid disruption.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if preferences.needsInitialDisclosure {
                        Text("By continuing, you acknowledge that ads and anonymous usage metrics help keep the app free.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Toggle(
                        "Allow personalized ads",
                        isOn: Binding(
                            get: { preferences.wantsPersonalizedAds },
                            set: { newValue in
                                Task { @MainActor in
                                    await preferences.setPersonalizedAdsRequested(newValue)
                                    AdRuntime.updateConsentConfiguration()
                                }
                            }
                        )
                    )

                    Text("Tracking status: \(preferences.trackingStatusDescription)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button("Reset ad preferences") {
                        preferences.resetPrivacyChoices()
                        AdRuntime.updateConsentConfiguration()
                    }
                    .font(.footnote.weight(.semibold))
                }

                Section("Safety Filters") {
                    Text("Blocked categories")
                        .font(.subheadline.weight(.semibold))
                    Text(AdContentRules.blockedCategorySummary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Data disclosure") {
                    Text("Collected on device: profile details, task completion state, and ad preference settings.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("Potential third parties (if enabled): Google Sign-In and Google AdMob.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Legal and support") {
                    if let url = ExternalURLPolicy.normalizedURL(from: AdLegal.privacyPolicyURL) {
                        Link("Open privacy policy", destination: url)
                    }
                    if let url = ExternalURLPolicy.normalizedURL(from: AdLegal.termsOfServiceURL) {
                        Link("Open terms of service", destination: url)
                    }
                    if let url = ExternalURLPolicy.normalizedURL(from: AdLegal.dataDeletionURL) {
                        Link("Request data deletion", destination: url)
                    }
                    if let url = ExternalURLPolicy.normalizedURL(from: AdLegal.supportURL) {
                        Link("Open support center", destination: url)
                    }
                    if let supportEmailURL = AppConfig.legal.supportEmailURL {
                        Link("Email support", destination: supportEmailURL)
                    }
                }
            }
            .navigationTitle("Ad & Privacy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { close() }
                }
            }
        }
    }

    private func close() {
        preferences.updateDisclosureAccepted()
        AdRuntime.updateConsentConfiguration()
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }
}

private struct HelpSheet: View {
    var onOpenAdPrivacy: () -> Void
    var onOpenEmergencyContacts: () -> Void
    var onOpenPrivacy: () -> Void
    var onClose: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Theme.spaceS) {
                Text("Help")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.primaryText)
                Spacer()
                Button("Done") { close() }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.linkText)
                    .buttonStyle(AppFastButtonStyle())
            }
            .padding(.horizontal, Theme.spaceXL)
            .padding(.top, Theme.spaceM)
            .padding(.bottom, Theme.spaceS)

            Divider()
                .overlay(Theme.stroke)

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spaceM) {
                    helpRow(
                        title: "Profile and sign in",
                        subtitle: "Manage Apple/Google login and student details in profile setup.",
                        icon: "person.crop.circle"
                    )

                    helpRow(
                        title: "Task details and official sources",
                        subtitle: "Open a task and use \"Open Official Guidance\" for verified links.",
                        icon: "doc.text.magnifyingglass"
                    )

                    helpRow(
                        title: "Ads and privacy controls",
                        subtitle: "Manage personalization and tracking settings.",
                        icon: "hand.raised"
                    ) {
                        onOpenAdPrivacy()
                    }

                    helpRow(
                        title: "Emergency contacts",
                        subtitle: "Call 999, NHS 111, and other key support lines quickly.",
                        icon: "phone.badge.checkmark"
                    ) {
                        onOpenEmergencyContacts()
                    }

                    helpRow(
                        title: "Privacy policy",
                        subtitle: "Review policy details and data handling.",
                        icon: "lock.shield"
                    ) {
                        onOpenPrivacy()
                    }

                    if let supportURL = ExternalURLPolicy.normalizedURL(from: "https://www.gov.uk/ukvi") {
                        Link(destination: supportURL) {
                            HStack(spacing: Theme.spaceS) {
                                Image(systemName: "arrow.up.right.square")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Theme.linkText)
                                Text("Open UKVI support website")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Theme.linkText)
                                Spacer()
                            }
                            .padding(Theme.spaceM)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous)
                                    .fill(Theme.terracotta50)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous)
                                    .stroke(Theme.terracotta200, lineWidth: 1)
                            )
                        }
                        .buttonStyle(AppFastButtonStyle())
                    }
                }
                .padding(.horizontal, Theme.spaceXL)
                .padding(.vertical, Theme.spaceM)
            }
        }
        .background(Theme.card)
    }

    @ViewBuilder
    private func helpRow(
        title: String,
        subtitle: String,
        icon: String,
        action: (() -> Void)? = nil
    ) -> some View {
        Group {
            if let action {
                Button(action: action) {
                    helpRowContent(title: title, subtitle: subtitle, icon: icon, showsChevron: true)
                }
                .buttonStyle(AppFastButtonStyle())
            } else {
                helpRowContent(title: title, subtitle: subtitle, icon: icon, showsChevron: false)
            }
        }
    }

    private func helpRowContent(
        title: String,
        subtitle: String,
        icon: String,
        showsChevron: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: Theme.spaceS) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.primaryText)
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.secondaryText)
            }

            Spacer()

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.tertiaryText)
                    .padding(.top, 2)
            }
        }
        .padding(Theme.spaceM)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous)
                .fill(Theme.gray50)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous)
                .stroke(Theme.stroke, lineWidth: 1)
        )
    }

    private func close() {
        onClose?()
    }
}

private struct PrivacyInfoSheet: View {
    var onClose: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Theme.spaceS) {
                Text("Privacy")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.primaryText)
                Spacer()
                Button("Done") { close() }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.linkText)
                    .buttonStyle(AppFastButtonStyle())
            }
            .padding(.horizontal, Theme.spaceXL)
            .padding(.top, Theme.spaceM)
            .padding(.bottom, Theme.spaceS)

            Divider()
                .overlay(Theme.stroke)

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spaceM) {
                    Text("We only show safe ad categories and block sensitive topics by default. You can control personalized ads from Ad & Privacy settings.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.secondaryText)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Data we store locally")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.primaryText)
                        Text("• Student profile details for checklist personalization")
                        Text("• Task completion progress and custom tasks")
                        Text("• Notification and ad-consent preferences")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.secondaryText)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Third-party services (if enabled)")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.primaryText)
                        Text("• Google Sign-In for authentication")
                        Text("• Google AdMob for advertising")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.secondaryText)

                    if let url = ExternalURLPolicy.normalizedURL(from: AdLegal.privacyPolicyURL) {
                        Link(destination: url) {
                            HStack(spacing: Theme.spaceS) {
                                Image(systemName: "lock.shield")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Open Privacy Policy")
                                    .font(.system(size: 15, weight: .semibold))
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundStyle(Theme.inverseText)
                            .padding(Theme.spaceM)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous)
                                    .fill(Theme.primaryButtonBackground)
                            )
                        }
                        .buttonStyle(AppFastButtonStyle())
                    }

                    if let termsURL = ExternalURLPolicy.normalizedURL(from: AdLegal.termsOfServiceURL) {
                        Link(destination: termsURL) {
                            HStack(spacing: Theme.spaceS) {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Open Terms of Service")
                                    .font(.system(size: 15, weight: .semibold))
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundStyle(Theme.linkText)
                            .padding(Theme.spaceM)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous)
                                    .fill(Theme.terracotta50)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous)
                                    .stroke(Theme.terracotta200, lineWidth: 1)
                            )
                        }
                        .buttonStyle(AppFastButtonStyle())
                    }

                    if let deletionURL = ExternalURLPolicy.normalizedURL(from: AdLegal.dataDeletionURL) {
                        Link("Request data deletion", destination: deletionURL)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.linkText)
                    }

                    if let supportEmailURL = AppConfig.legal.supportEmailURL {
                        Link("Email support", destination: supportEmailURL)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.linkText)
                    }
                }
                .padding(.horizontal, Theme.spaceXL)
                .padding(.vertical, Theme.spaceM)
            }
        }
        .background(Theme.card)
    }

    private func close() {
        onClose?()
    }
}



#Preview {
    ContentView()
}

```

## arrival uk/Core/AppConfig.swift

```swift
import Foundation

enum AppEnvironment: String {
    case development
    case staging
    case production

    static var current: AppEnvironment {
        #if DEBUG
        return .development
        #else
        return .production
        #endif
    }
}

struct FeatureFlags {
    var enableAds: Bool
    var enableAffiliateLinks: Bool
    var enableCommunity: Bool
    var enableChat: Bool
    var enableDecorativeEffects: Bool

    static var `default`: FeatureFlags {
        FeatureFlags(
            enableAds: true,
            enableAffiliateLinks: true,
            enableCommunity: false,
            enableChat: false,
            enableDecorativeEffects: true
        )
    }
}

struct LegalConfiguration {
    let privacyPolicyURL: URL
    let termsOfServiceURL: URL
    let supportWebsiteURL: URL
    let supportEmailAddress: String
    let dataDeletionRequestURL: URL

    var supportEmailURL: URL? {
        let subject = "[Your App Name] Support Request".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "mailto:\(supportEmailAddress)?subject=\(subject)")
    }
}

enum AppConfig {
    private static let fallbackURL = URL(string: "https://arrivaluk.app") ?? URL(fileURLWithPath: "/")

    private static func resolvedURL(_ rawValue: String) -> URL {
        URL(string: rawValue) ?? fallbackURL
    }

    static var environment: AppEnvironment { .current }

    static var apiBaseURL: URL {
        switch environment {
        case .development:
            return resolvedURL("https://api-dev.arrivaluk.app")
        case .staging:
            return resolvedURL("https://api-staging.arrivaluk.app")
        case .production:
            return resolvedURL("https://api.arrivaluk.app")
        }
    }

    static let requestTimeout: TimeInterval = 30
    static let resourceTimeout: TimeInterval = 60
    static let maxNetworkRetries: Int = 3
    static let launchWatchdogDelayNanoseconds: UInt64 = 1_500_000_000
    static let progressPersistDebounceNanoseconds: UInt64 = 350_000_000
    static let crashReportingEnabled = true

    static let legal = LegalConfiguration(
        privacyPolicyURL: resolvedURL("https://arrivaluk.app/privacy"),
        termsOfServiceURL: resolvedURL("https://arrivaluk.app/terms"),
        supportWebsiteURL: resolvedURL("https://arrivaluk.app/support"),
        supportEmailAddress: "support@arrivaluk.app",
        dataDeletionRequestURL: resolvedURL("https://arrivaluk.app/delete-data")
    )

    static var features: FeatureFlags {
        var value = FeatureFlags.default

        #if DEBUG
        value.enableCommunity = true
        #endif

        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            value.enableDecorativeEffects = false
        }

        return value
    }
}

```

## arrival uk/Core/CrashReporter.swift

```swift
import Foundation
import os

#if canImport(FirebaseCore)
import FirebaseCore
#endif

#if canImport(FirebaseCrashlytics)
import FirebaseCrashlytics
#endif

enum CrashLogLevel {
    case debug
    case info
    case warning
    case error
    case critical
}

/// Centralized crash and diagnostics reporting.
/// Works without Firebase, and automatically forwards logs/errors to Crashlytics when linked.
enum CrashReporter {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.arrivaluk.app",
        category: "crash-reporter"
    )
    private static let syncQueue = DispatchQueue(label: "com.arrivaluk.crash-reporter")
    private static var didBootstrap = false

    static func bootstrapIfNeeded() {
        syncQueue.sync {
            guard !didBootstrap else { return }
            didBootstrap = true
        }

        #if canImport(FirebaseCore)
        if FirebaseApp.app() == nil {
            if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
                FirebaseApp.configure()
            } else {
                logger.warning("GoogleService-Info.plist missing; Firebase not configured in this build")
            }
        }
        #endif

        let environment = AppConfig.environment.rawValue
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"

        #if canImport(FirebaseCrashlytics)
        let crashlytics = Crashlytics.crashlytics()
        crashlytics.setCustomValue(environment, forKey: "app_environment")
        crashlytics.setCustomValue(version, forKey: "app_version")
        crashlytics.setCustomValue(build, forKey: "app_build")
        crashlytics.log("CrashReporter bootstrapped env=\(environment) version=\(version) build=\(build)")
        #endif

        log("CrashReporter bootstrapped env=\(environment) version=\(version) build=\(build)", level: .info)
    }

    static func setUserIdentifier(_ identifier: String?) {
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().setUserID(identifier ?? "")
        #endif
    }

    static func log(_ message: String, level: CrashLogLevel = .info) {
        switch level {
        case .debug:
            #if DEBUG
            logger.debug("\(message, privacy: .public)")
            #endif
        case .info:
            logger.info("\(message, privacy: .public)")
        case .warning:
            logger.warning("\(message, privacy: .public)")
        case .error, .critical:
            logger.error("\(message, privacy: .public)")
        }

        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().log("[\(String(describing: level).uppercased())] \(message)")
        #endif
    }

    static func record(
        error: Error,
        context: String,
        metadata: [String: String] = [:]
    ) {
        let nsError = error as NSError
        logger.error(
            "nonfatal context=\(context, privacy: .public) domain=\(nsError.domain, privacy: .public) code=\(nsError.code)"
        )

        #if canImport(FirebaseCrashlytics)
        let crashlytics = Crashlytics.crashlytics()
        crashlytics.setCustomValue(context, forKey: "last_error_context")
        if !metadata.isEmpty {
            crashlytics.setCustomValue(metadata, forKey: "last_error_metadata")
        }
        crashlytics.record(error: nsError)
        #endif
    }
}

```

## arrival uk/Data/categories.json

```json
{
  "categories": [
    {
      "id": "before_arrival",
      "title": "Before Arrival",
      "subtitle": "Must complete before landing",
      "categoryType": "arrival",
      "icon": "airplane.departure",
      "gradient": [
        "#667EEA",
        "#764BA2"
      ],
      "priority": "critical",
      "urgency": "immediate",
      "order": 1,
      "tasks": [
        {
          "id": "before_visa_check",
          "title": "Confirm visa documents are complete",
          "detail": "Double-check passport validity, CAS details, and proof of funds before travel.",
          "timing": "month_before_arrival",
          "priority": "must_do",
          "sourceTitle": "UK Student Visa Guidance (GOV.UK)",
          "sourceURL": "https://www.gov.uk/student-visa"
        },
        {
          "id": "before_uni_letter",
          "title": "Download university status letter template",
          "detail": "Prepare a digital copy so bank account and admin steps are faster after arrival.",
          "timing": "week_before_arrival",
          "priority": "should_do"
        },
        {
          "id": "before_housing_docs",
          "title": "Prepare housing and ID document pack",
          "detail": "Keep tenancy agreement, passport, visa proof, and offer letter in one folder.",
          "timing": "week_before_arrival",
          "priority": "must_do"
        },
        {
          "id": "before_budget",
          "title": "Set first-month budget",
          "detail": "Estimate rent, groceries, transport, and emergency spending for your first month.",
          "timing": "week_before_arrival",
          "priority": "should_do"
        }
      ]
    },
    {
      "id": "academic_setup",
      "title": "Academic Setup",
      "subtitle": "Get course systems ready",
      "categoryType": "academic",
      "icon": "graduationcap.fill",
      "gradient": [
        "#FA709A",
        "#FEE140"
      ],
      "priority": "high",
      "urgency": "week1",
      "order": 2,
      "tasks": [
        {
          "id": "academic_portal_login",
          "title": "Access university portal",
          "detail": "Activate your student account and verify email + timetable access.",
          "timing": "first_week",
          "priority": "must_do"
        },
        {
          "id": "academic_module_registration",
          "title": "Register modules",
          "detail": "Submit module choices before the deadline and keep confirmation screenshots.",
          "timing": "first_week",
          "priority": "must_do"
        },
        {
          "id": "academic_library_access",
          "title": "Set up library access",
          "detail": "Enable online journals, borrowing rights, and off-campus VPN access.",
          "timing": "first_month",
          "priority": "should_do"
        }
      ]
    },
    {
      "id": "health_admin",
      "title": "Health & Admin",
      "subtitle": "Legal and healthcare setup",
      "categoryType": "wellness",
      "icon": "cross.case.fill",
      "gradient": [
        "#FF6B9D",
        "#FFA06B"
      ],
      "priority": "high",
      "urgency": "week1",
      "order": 3,
      "tasks": [
        {
          "id": "health_gp",
          "title": "Register with a GP surgery",
          "detail": "Do this soon after settling so healthcare access is ready when needed.",
          "timing": "first_week",
          "priority": "must_do",
          "sourceTitle": "NHS GP Registration",
          "sourceURL": "https://www.nhs.uk/nhs-services/gps/how-to-register-with-a-gp-surgery/"
        },
        {
          "id": "health_ni",
          "title": "Apply for National Insurance number",
          "detail": "Needed for legal work and correct tax setup.",
          "timing": "first_month",
          "priority": "must_do",
          "sourceTitle": "Apply for National Insurance Number",
          "sourceURL": "https://www.gov.uk/apply-national-insurance-number"
        },
        {
          "id": "health_council_tax",
          "title": "Submit council tax exemption",
          "detail": "Use student proof to avoid paying full council tax where eligible.",
          "timing": "first_month",
          "priority": "should_do"
        }
      ]
    },
    {
      "id": "money_banking",
      "title": "Money & Banking",
      "subtitle": "Money setup and daily finance",
      "categoryType": "finance",
      "icon": "sterlingsign.circle.fill",
      "gradient": [
        "#FFD89B",
        "#19547B"
      ],
      "priority": "high",
      "urgency": "week1",
      "order": 4,
      "tasks": [
        {
          "id": "money_open_account",
          "title": "Open a UK bank account",
          "detail": "Compare student accounts and keep enrollment proof ready.",
          "timing": "first_week",
          "priority": "must_do"
        },
        {
          "id": "money_enable_alerts",
          "title": "Enable spending alerts",
          "detail": "Turn on transaction notifications to avoid overspending.",
          "timing": "first_week",
          "priority": "should_do"
        },
        {
          "id": "money_setup_buffer",
          "title": "Create emergency buffer",
          "detail": "Set a minimum reserve for unexpected costs.",
          "timing": "first_month",
          "priority": "optional"
        },
        {
          "id": "money_budget_sheet",
          "title": "Create monthly budget sheet",
          "detail": "Track rent, groceries, transport, and subscriptions.",
          "timing": "first_month",
          "priority": "should_do"
        }
      ]
    },
    {
      "id": "housing",
      "title": "Housing & Accommodation",
      "subtitle": "Set up safe and legal housing",
      "categoryType": "housing",
      "icon": "house.fill",
      "gradient": [
        "#74EBD5",
        "#9FACE6"
      ],
      "priority": "high",
      "urgency": "week1",
      "order": 5,
      "tasks": [
        {
          "id": "housing_contract_review",
          "title": "Review tenancy agreement",
          "detail": "Check notice period, deposit protection, and included bills.",
          "timing": "week_before_arrival",
          "priority": "must_do"
        },
        {
          "id": "housing_inventory_photos",
          "title": "Take move-in inventory photos",
          "detail": "Document room condition on day one to avoid deposit disputes.",
          "timing": "first_week",
          "priority": "must_do"
        },
        {
          "id": "housing_utilities_check",
          "title": "Confirm utility setup",
          "detail": "Verify electricity, heating, and water are active and billed correctly.",
          "timing": "first_week",
          "priority": "should_do"
        },
        {
          "id": "housing_landlord_contact",
          "title": "Save landlord and emergency contact",
          "detail": "Keep contact details accessible for urgent repairs.",
          "timing": "first_week",
          "priority": "should_do"
        },
        {
          "id": "housing_contents_check",
          "title": "Consider contents insurance",
          "detail": "Protect your laptop and valuables in shared accommodation.",
          "timing": "first_month",
          "priority": "optional"
        }
      ]
    },
    {
      "id": "work_career",
      "title": "Work & Career",
      "subtitle": "Build legal work readiness",
      "categoryType": "career",
      "icon": "briefcase.fill",
      "gradient": [
        "#A8EDEA",
        "#FED6E3"
      ],
      "priority": "medium",
      "urgency": "week2",
      "order": 6,
      "tasks": [
        {
          "id": "work_career_cv",
          "title": "Prepare UK-style CV",
          "detail": "Adapt format for UK employers and include availability.",
          "timing": "first_month",
          "priority": "should_do"
        },
        {
          "id": "work_career_hours",
          "title": "Understand visa work limits",
          "detail": "Confirm term-time and vacation working hour restrictions.",
          "timing": "first_week",
          "priority": "must_do"
        },
        {
          "id": "work_career_accounts",
          "title": "Create job platform profiles",
          "detail": "Set up LinkedIn and student job portals with alerts.",
          "timing": "first_month",
          "priority": "optional"
        }
      ]
    },
    {
      "id": "travel_transport",
      "title": "Travel & Transport",
      "subtitle": "Move around affordably",
      "categoryType": "transport",
      "icon": "tram.fill",
      "gradient": [
        "#11998E",
        "#38EF7D"
      ],
      "priority": "medium",
      "urgency": "week2",
      "order": 7,
      "tasks": [
        {
          "id": "travel_oyster",
          "title": "Set up local transport card",
          "detail": "Get Oyster/region card and connect contactless payment.",
          "timing": "first_week",
          "priority": "must_do"
        },
        {
          "id": "travel_railcard",
          "title": "Apply for student railcard",
          "detail": "Reduce long-distance train costs across the UK.",
          "timing": "first_month",
          "priority": "should_do"
        },
        {
          "id": "travel_routes",
          "title": "Save key routes",
          "detail": "Pin university, accommodation, GP, and station routes.",
          "timing": "first_week",
          "priority": "should_do"
        },
        {
          "id": "travel_night_safety",
          "title": "Plan safe night transport",
          "detail": "Know late bus/train options and trusted taxi apps.",
          "timing": "first_month",
          "priority": "optional"
        }
      ]
    },
    {
      "id": "legal_docs",
      "title": "Legal & Documentation",
      "subtitle": "Keep records clean and compliant",
      "categoryType": "legal",
      "icon": "doc.text.fill",
      "gradient": [
        "#B490CA",
        "#5EE7DF"
      ],
      "priority": "medium",
      "urgency": "week2",
      "order": 8,
      "tasks": [
        {
          "id": "legal_copy_docs",
          "title": "Create secure digital copies",
          "detail": "Store passport, visa, BRP, and tenancy copies in encrypted storage.",
          "timing": "first_week",
          "priority": "must_do"
        },
        {
          "id": "legal_brp_collection",
          "title": "Confirm BRP/eVisa status",
          "detail": "Check current UKVI process and collection deadlines.",
          "timing": "first_week",
          "priority": "must_do"
        },
        {
          "id": "legal_deadline_tracker",
          "title": "Track key legal deadlines",
          "detail": "Set reminders for visa, tenancy, and enrollment deadlines.",
          "timing": "first_month",
          "priority": "should_do"
        }
      ]
    },
    {
      "id": "shopping_essentials",
      "title": "Shopping Essentials",
      "subtitle": "Set up core living supplies",
      "categoryType": "shopping",
      "icon": "bag.fill",
      "gradient": [
        "#FC6C8F",
        "#F89B6D"
      ],
      "priority": "medium",
      "urgency": "week1",
      "order": 9,
      "tasks": [
        {
          "id": "shopping_bedding",
          "title": "Buy bedding and room essentials",
          "detail": "Prioritize bedding, toiletries, and cleaning supplies for first week.",
          "timing": "first_week",
          "priority": "must_do"
        },
        {
          "id": "shopping_kitchen",
          "title": "Build basic kitchen kit",
          "detail": "Get reusable containers, pan, knife, mug, and cutlery.",
          "timing": "first_week",
          "priority": "should_do"
        },
        {
          "id": "shopping_grocery_apps",
          "title": "Install grocery and deal apps",
          "detail": "Use apps for delivery windows, coupons, and student discounts.",
          "timing": "first_week",
          "priority": "should_do"
        },
        {
          "id": "shopping_compare_prices",
          "title": "Compare local store pricing",
          "detail": "Identify low-cost weekly shopping route.",
          "timing": "first_month",
          "priority": "optional"
        },
        {
          "id": "shopping_secondhand",
          "title": "Check second-hand options",
          "detail": "Save money with verified second-hand marketplaces.",
          "timing": "first_month",
          "priority": "optional"
        },
        {
          "id": "shopping_winter_gear",
          "title": "Prepare weather-appropriate clothing",
          "detail": "Plan for rain and winter temperature shifts.",
          "timing": "first_month",
          "priority": "should_do"
        }
      ]
    },
    {
      "id": "communication_setup",
      "title": "Communication Setup",
      "subtitle": "Keep reliable contact channels",
      "categoryType": "communication",
      "icon": "iphone",
      "gradient": [
        "#56CCF2",
        "#2F80ED"
      ],
      "priority": "medium",
      "urgency": "week1",
      "order": 10,
      "tasks": [
        {
          "id": "communication_sim",
          "title": "Get UK SIM card",
          "detail": "Compare plans and activate a UK number for banking and services.",
          "timing": "first_week",
          "priority": "must_do"
        },
        {
          "id": "communication_emergency_contacts",
          "title": "Save emergency and university contacts",
          "detail": "Store critical numbers for support and emergencies.",
          "timing": "first_week",
          "priority": "must_do"
        }
      ]
    },
    {
      "id": "insurance_safety",
      "title": "Insurance & Safety",
      "subtitle": "Protect yourself and belongings",
      "categoryType": "insurance",
      "icon": "shield.fill",
      "gradient": [
        "#A8E063",
        "#56AB2F"
      ],
      "priority": "medium",
      "urgency": "week2",
      "order": 11,
      "tasks": [
        {
          "id": "insurance_health_cover",
          "title": "Review health coverage",
          "detail": "Understand NHS eligibility and any private insurance needs.",
          "timing": "first_month",
          "priority": "should_do"
        },
        {
          "id": "insurance_property",
          "title": "Consider contents insurance",
          "detail": "Protect electronics and valuables in shared accommodation.",
          "timing": "first_month",
          "priority": "optional"
        },
        {
          "id": "insurance_local_safety",
          "title": "Learn local safety basics",
          "detail": "Identify safe routes, emergency numbers, and campus resources.",
          "timing": "first_week",
          "priority": "must_do"
        }
      ]
    },
    {
      "id": "student_discounts",
      "title": "Student Discounts",
      "subtitle": "Reduce ongoing monthly spend",
      "categoryType": "discounts",
      "icon": "creditcard.fill",
      "gradient": [
        "#FA8BFF",
        "#2BD2FF"
      ],
      "priority": "low",
      "urgency": "anytime",
      "order": 12,
      "tasks": [
        {
          "id": "discounts_totum",
          "title": "Apply for TOTUM/UNiDAYS",
          "detail": "Unlock verified student discounts across brands.",
          "timing": "first_month",
          "priority": "should_do"
        },
        {
          "id": "discounts_transport",
          "title": "Enable transport student discounts",
          "detail": "Link your student status for travel savings.",
          "timing": "first_month",
          "priority": "should_do"
        },
        {
          "id": "discounts_grocery",
          "title": "Track weekly discount windows",
          "detail": "Use scheduled offers from local supermarkets.",
          "timing": "ongoing",
          "priority": "optional"
        },
        {
          "id": "discounts_software",
          "title": "Claim software student plans",
          "detail": "Get discounted cloud storage and productivity tools.",
          "timing": "first_month",
          "priority": "optional"
        },
        {
          "id": "discounts_entertainment",
          "title": "Set entertainment budget caps",
          "detail": "Use student plans without overspending.",
          "timing": "ongoing",
          "priority": "optional"
        }
      ]
    },
    {
      "id": "internet_tech",
      "title": "Internet & Tech",
      "subtitle": "Keep devices and access reliable",
      "categoryType": "internet",
      "icon": "wifi",
      "gradient": [
        "#4FACFE",
        "#00F2FE"
      ],
      "priority": "low",
      "urgency": "week1",
      "order": 13,
      "tasks": [
        {
          "id": "internet_broadband",
          "title": "Confirm home broadband",
          "detail": "Check speed, contract terms, and installation date.",
          "timing": "first_week",
          "priority": "must_do"
        },
        {
          "id": "internet_backup_data",
          "title": "Set mobile data backup",
          "detail": "Prepare hotspot fallback for study deadlines.",
          "timing": "first_week",
          "priority": "should_do"
        },
        {
          "id": "internet_security",
          "title": "Secure your devices",
          "detail": "Enable updates, password manager, and 2FA.",
          "timing": "first_month",
          "priority": "should_do"
        }
      ]
    },
    {
      "id": "social_networking",
      "title": "Social & Networking",
      "subtitle": "Build support and opportunities",
      "categoryType": "social",
      "icon": "person.3.fill",
      "gradient": [
        "#FFD3A5",
        "#FD6585"
      ],
      "priority": "low",
      "urgency": "anytime",
      "order": 14,
      "tasks": [
        {
          "id": "social_join_groups",
          "title": "Join student groups",
          "detail": "Find official course and international student communities.",
          "timing": "first_week",
          "priority": "should_do"
        },
        {
          "id": "social_attend_events",
          "title": "Attend welcome events",
          "detail": "Use early events to build your support network.",
          "timing": "first_month",
          "priority": "should_do"
        },
        {
          "id": "social_mentors",
          "title": "Connect with mentors",
          "detail": "Identify peer mentors for study and city guidance.",
          "timing": "first_month",
          "priority": "optional"
        },
        {
          "id": "social_boundaries",
          "title": "Set healthy social boundaries",
          "detail": "Balance academics, wellbeing, and social commitments.",
          "timing": "ongoing",
          "priority": "optional"
        }
      ]
    },
    {
      "id": "student_life",
      "title": "Student Life Essentials",
      "subtitle": "Build sustainable routines",
      "categoryType": "lifestyle",
      "icon": "backpack.fill",
      "gradient": [
        "#FFA8A8",
        "#FCFF00"
      ],
      "priority": "low",
      "urgency": "anytime",
      "order": 15,
      "tasks": [
        {
          "id": "life_weekly_planning",
          "title": "Set weekly planning routine",
          "detail": "Use one weekly review to plan study, work, and errands.",
          "timing": "ongoing",
          "priority": "should_do"
        },
        {
          "id": "life_health_habits",
          "title": "Track sleep and meal habits",
          "detail": "Create a sustainable routine for energy and focus.",
          "timing": "ongoing",
          "priority": "optional"
        },
        {
          "id": "life_financial_checkin",
          "title": "Monthly financial check-in",
          "detail": "Review budget drift and adjust spending targets.",
          "timing": "ongoing",
          "priority": "should_do"
        },
        {
          "id": "life_admin_cleanup",
          "title": "Monthly admin cleanup",
          "detail": "Organize digital files, receipts, and official emails.",
          "timing": "ongoing",
          "priority": "optional"
        },
        {
          "id": "life_personal_goals",
          "title": "Set personal learning goals",
          "detail": "Define skill-building goals outside coursework.",
          "timing": "ongoing",
          "priority": "optional"
        },
        {
          "id": "life_support_network",
          "title": "Maintain support check-ins",
          "detail": "Keep regular contact with trusted friends/family.",
          "timing": "ongoing",
          "priority": "optional"
        },
        {
          "id": "life_document_backups",
          "title": "Back up important documents",
          "detail": "Keep secure copies of IDs, banking, and study files.",
          "timing": "ongoing",
          "priority": "should_do"
        },
        {
          "id": "life_review_progress",
          "title": "Review progress each month",
          "detail": "Track completed tasks and identify next priorities.",
          "timing": "ongoing",
          "priority": "should_do"
        }
      ]
    }
  ]
}

```

## arrival uk/Data/content.json

```json
{
  "categories": [
    {
      "id": "before_arrival",
      "title": "Before Arrival",
      "subtitle": "Must complete before landing",
      "categoryType": "arrival",
      "icon": "airplane.departure",
      "gradient": [
        "#667EEA",
        "#764BA2"
      ],
      "priority": "critical",
      "urgency": "immediate",
      "order": 1,
      "tasks": [
        {
          "id": "before_visa_check",
          "title": "Confirm visa documents are complete",
          "detail": "Double-check passport validity, CAS details, and proof of funds before travel.",
          "timing": "month_before_arrival",
          "priority": "must_do",
          "sourceTitle": "UK Student Visa Guidance (GOV.UK)",
          "sourceURL": "https://www.gov.uk/student-visa"
        },
        {
          "id": "before_uni_letter",
          "title": "Download university status letter template",
          "detail": "Prepare a digital copy so bank account and admin steps are faster after arrival.",
          "timing": "week_before_arrival",
          "priority": "should_do"
        },
        {
          "id": "before_housing_docs",
          "title": "Prepare housing and ID document pack",
          "detail": "Keep tenancy agreement, passport, visa proof, and offer letter in one folder.",
          "timing": "week_before_arrival",
          "priority": "must_do"
        },
        {
          "id": "before_budget",
          "title": "Set first-month budget",
          "detail": "Estimate rent, groceries, transport, and emergency spending for your first month.",
          "timing": "week_before_arrival",
          "priority": "should_do"
        }
      ]
    },
    {
      "id": "academic_setup",
      "title": "Academic Setup",
      "subtitle": "Get course systems ready",
      "categoryType": "academic",
      "icon": "graduationcap.fill",
      "gradient": [
        "#FA709A",
        "#FEE140"
      ],
      "priority": "high",
      "urgency": "week1",
      "order": 2,
      "tasks": [
        {
          "id": "academic_portal_login",
          "title": "Access university portal",
          "detail": "Activate your student account and verify email + timetable access.",
          "timing": "first_week",
          "priority": "must_do"
        },
        {
          "id": "academic_module_registration",
          "title": "Register modules",
          "detail": "Submit module choices before the deadline and keep confirmation screenshots.",
          "timing": "first_week",
          "priority": "must_do"
        },
        {
          "id": "academic_library_access",
          "title": "Set up library access",
          "detail": "Enable online journals, borrowing rights, and off-campus VPN access.",
          "timing": "first_month",
          "priority": "should_do"
        }
      ]
    },
    {
      "id": "health_admin",
      "title": "Health & Admin",
      "subtitle": "Legal and healthcare setup",
      "categoryType": "wellness",
      "icon": "cross.case.fill",
      "gradient": [
        "#FF6B9D",
        "#FFA06B"
      ],
      "priority": "high",
      "urgency": "week1",
      "order": 3,
      "tasks": [
        {
          "id": "health_gp",
          "title": "Register with a GP surgery",
          "detail": "Do this soon after settling so healthcare access is ready when needed.",
          "timing": "first_week",
          "priority": "must_do",
          "sourceTitle": "NHS GP Registration",
          "sourceURL": "https://www.nhs.uk/nhs-services/gps/how-to-register-with-a-gp-surgery/"
        },
        {
          "id": "health_ni",
          "title": "Apply for National Insurance number",
          "detail": "Needed for legal work and correct tax setup.",
          "timing": "first_month",
          "priority": "must_do",
          "sourceTitle": "Apply for National Insurance Number",
          "sourceURL": "https://www.gov.uk/apply-national-insurance-number"
        },
        {
          "id": "health_council_tax",
          "title": "Submit council tax exemption",
          "detail": "Use student proof to avoid paying full council tax where eligible.",
          "timing": "first_month",
          "priority": "should_do"
        }
      ]
    },
    {
      "id": "money_banking",
      "title": "Money & Banking",
      "subtitle": "Money setup and daily finance",
      "categoryType": "finance",
      "icon": "sterlingsign.circle.fill",
      "gradient": [
        "#FFD89B",
        "#19547B"
      ],
      "priority": "high",
      "urgency": "week1",
      "order": 4,
      "tasks": [
        {
          "id": "money_open_account",
          "title": "Open a UK bank account",
          "detail": "Compare student accounts and keep enrollment proof ready.",
          "timing": "first_week",
          "priority": "must_do"
        },
        {
          "id": "money_enable_alerts",
          "title": "Enable spending alerts",
          "detail": "Turn on transaction notifications to avoid overspending.",
          "timing": "first_week",
          "priority": "should_do"
        },
        {
          "id": "money_setup_buffer",
          "title": "Create emergency buffer",
          "detail": "Set a minimum reserve for unexpected costs.",
          "timing": "first_month",
          "priority": "optional"
        },
        {
          "id": "money_budget_sheet",
          "title": "Create monthly budget sheet",
          "detail": "Track rent, groceries, transport, and subscriptions.",
          "timing": "first_month",
          "priority": "should_do"
        }
      ]
    },
    {
      "id": "housing",
      "title": "Housing & Accommodation",
      "subtitle": "Set up safe and legal housing",
      "categoryType": "housing",
      "icon": "house.fill",
      "gradient": [
        "#74EBD5",
        "#9FACE6"
      ],
      "priority": "high",
      "urgency": "week1",
      "order": 5,
      "tasks": [
        {
          "id": "housing_contract_review",
          "title": "Review tenancy agreement",
          "detail": "Check notice period, deposit protection, and included bills.",
          "timing": "week_before_arrival",
          "priority": "must_do"
        },
        {
          "id": "housing_inventory_photos",
          "title": "Take move-in inventory photos",
          "detail": "Document room condition on day one to avoid deposit disputes.",
          "timing": "first_week",
          "priority": "must_do"
        },
        {
          "id": "housing_utilities_check",
          "title": "Confirm utility setup",
          "detail": "Verify electricity, heating, and water are active and billed correctly.",
          "timing": "first_week",
          "priority": "should_do"
        },
        {
          "id": "housing_landlord_contact",
          "title": "Save landlord and emergency contact",
          "detail": "Keep contact details accessible for urgent repairs.",
          "timing": "first_week",
          "priority": "should_do"
        },
        {
          "id": "housing_contents_check",
          "title": "Consider contents insurance",
          "detail": "Protect your laptop and valuables in shared accommodation.",
          "timing": "first_month",
          "priority": "optional"
        }
      ]
    },
    {
      "id": "work_career",
      "title": "Work & Career",
      "subtitle": "Build legal work readiness",
      "categoryType": "career",
      "icon": "briefcase.fill",
      "gradient": [
        "#A8EDEA",
        "#FED6E3"
      ],
      "priority": "medium",
      "urgency": "week2",
      "order": 6,
      "tasks": [
        {
          "id": "work_career_cv",
          "title": "Prepare UK-style CV",
          "detail": "Adapt format for UK employers and include availability.",
          "timing": "first_month",
          "priority": "should_do"
        },
        {
          "id": "work_career_hours",
          "title": "Understand visa work limits",
          "detail": "Confirm term-time and vacation working hour restrictions.",
          "timing": "first_week",
          "priority": "must_do"
        },
        {
          "id": "work_career_accounts",
          "title": "Create job platform profiles",
          "detail": "Set up LinkedIn and student job portals with alerts.",
          "timing": "first_month",
          "priority": "optional"
        }
      ]
    },
    {
      "id": "travel_transport",
      "title": "Travel & Transport",
      "subtitle": "Move around affordably",
      "categoryType": "transport",
      "icon": "tram.fill",
      "gradient": [
        "#11998E",
        "#38EF7D"
      ],
      "priority": "medium",
      "urgency": "week2",
      "order": 7,
      "tasks": [
        {
          "id": "travel_oyster",
          "title": "Set up local transport card",
          "detail": "Get Oyster/region card and connect contactless payment.",
          "timing": "first_week",
          "priority": "must_do"
        },
        {
          "id": "travel_railcard",
          "title": "Apply for student railcard",
          "detail": "Reduce long-distance train costs across the UK.",
          "timing": "first_month",
          "priority": "should_do"
        },
        {
          "id": "travel_routes",
          "title": "Save key routes",
          "detail": "Pin university, accommodation, GP, and station routes.",
          "timing": "first_week",
          "priority": "should_do"
        },
        {
          "id": "travel_night_safety",
          "title": "Plan safe night transport",
          "detail": "Know late bus/train options and trusted taxi apps.",
          "timing": "first_month",
          "priority": "optional"
        }
      ]
    },
    {
      "id": "legal_docs",
      "title": "Legal & Documentation",
      "subtitle": "Keep records clean and compliant",
      "categoryType": "legal",
      "icon": "doc.text.fill",
      "gradient": [
        "#B490CA",
        "#5EE7DF"
      ],
      "priority": "medium",
      "urgency": "week2",
      "order": 8,
      "tasks": [
        {
          "id": "legal_copy_docs",
          "title": "Create secure digital copies",
          "detail": "Store passport, visa, BRP, and tenancy copies in encrypted storage.",
          "timing": "first_week",
          "priority": "must_do"
        },
        {
          "id": "legal_brp_collection",
          "title": "Confirm BRP/eVisa status",
          "detail": "Check current UKVI process and collection deadlines.",
          "timing": "first_week",
          "priority": "must_do"
        },
        {
          "id": "legal_deadline_tracker",
          "title": "Track key legal deadlines",
          "detail": "Set reminders for visa, tenancy, and enrollment deadlines.",
          "timing": "first_month",
          "priority": "should_do"
        }
      ]
    },
    {
      "id": "shopping_essentials",
      "title": "Shopping Essentials",
      "subtitle": "Set up core living supplies",
      "categoryType": "shopping",
      "icon": "bag.fill",
      "gradient": [
        "#FC6C8F",
        "#F89B6D"
      ],
      "priority": "medium",
      "urgency": "week1",
      "order": 9,
      "tasks": [
        {
          "id": "shopping_bedding",
          "title": "Buy bedding and room essentials",
          "detail": "Prioritize bedding, toiletries, and cleaning supplies for first week.",
          "timing": "first_week",
          "priority": "must_do"
        },
        {
          "id": "shopping_kitchen",
          "title": "Build basic kitchen kit",
          "detail": "Get reusable containers, pan, knife, mug, and cutlery.",
          "timing": "first_week",
          "priority": "should_do"
        },
        {
          "id": "shopping_grocery_apps",
          "title": "Install grocery and deal apps",
          "detail": "Use apps for delivery windows, coupons, and student discounts.",
          "timing": "first_week",
          "priority": "should_do"
        },
        {
          "id": "shopping_compare_prices",
          "title": "Compare local store pricing",
          "detail": "Identify low-cost weekly shopping route.",
          "timing": "first_month",
          "priority": "optional"
        },
        {
          "id": "shopping_secondhand",
          "title": "Check second-hand options",
          "detail": "Save money with verified second-hand marketplaces.",
          "timing": "first_month",
          "priority": "optional"
        },
        {
          "id": "shopping_winter_gear",
          "title": "Prepare weather-appropriate clothing",
          "detail": "Plan for rain and winter temperature shifts.",
          "timing": "first_month",
          "priority": "should_do"
        }
      ]
    },
    {
      "id": "communication_setup",
      "title": "Communication Setup",
      "subtitle": "Keep reliable contact channels",
      "categoryType": "communication",
      "icon": "iphone",
      "gradient": [
        "#56CCF2",
        "#2F80ED"
      ],
      "priority": "medium",
      "urgency": "week1",
      "order": 10,
      "tasks": [
        {
          "id": "communication_sim",
          "title": "Get UK SIM card",
          "detail": "Compare plans and activate a UK number for banking and services.",
          "timing": "first_week",
          "priority": "must_do"
        },
        {
          "id": "communication_emergency_contacts",
          "title": "Save emergency and university contacts",
          "detail": "Store critical numbers for support and emergencies.",
          "timing": "first_week",
          "priority": "must_do"
        }
      ]
    },
    {
      "id": "insurance_safety",
      "title": "Insurance & Safety",
      "subtitle": "Protect yourself and belongings",
      "categoryType": "insurance",
      "icon": "shield.fill",
      "gradient": [
        "#A8E063",
        "#56AB2F"
      ],
      "priority": "medium",
      "urgency": "week2",
      "order": 11,
      "tasks": [
        {
          "id": "insurance_health_cover",
          "title": "Review health coverage",
          "detail": "Understand NHS eligibility and any private insurance needs.",
          "timing": "first_month",
          "priority": "should_do"
        },
        {
          "id": "insurance_property",
          "title": "Consider contents insurance",
          "detail": "Protect electronics and valuables in shared accommodation.",
          "timing": "first_month",
          "priority": "optional"
        },
        {
          "id": "insurance_local_safety",
          "title": "Learn local safety basics",
          "detail": "Identify safe routes, emergency numbers, and campus resources.",
          "timing": "first_week",
          "priority": "must_do"
        }
      ]
    },
    {
      "id": "student_discounts",
      "title": "Student Discounts",
      "subtitle": "Reduce ongoing monthly spend",
      "categoryType": "discounts",
      "icon": "creditcard.fill",
      "gradient": [
        "#FA8BFF",
        "#2BD2FF"
      ],
      "priority": "low",
      "urgency": "anytime",
      "order": 12,
      "tasks": [
        {
          "id": "discounts_totum",
          "title": "Apply for TOTUM/UNiDAYS",
          "detail": "Unlock verified student discounts across brands.",
          "timing": "first_month",
          "priority": "should_do"
        },
        {
          "id": "discounts_transport",
          "title": "Enable transport student discounts",
          "detail": "Link your student status for travel savings.",
          "timing": "first_month",
          "priority": "should_do"
        },
        {
          "id": "discounts_grocery",
          "title": "Track weekly discount windows",
          "detail": "Use scheduled offers from local supermarkets.",
          "timing": "ongoing",
          "priority": "optional"
        },
        {
          "id": "discounts_software",
          "title": "Claim software student plans",
          "detail": "Get discounted cloud storage and productivity tools.",
          "timing": "first_month",
          "priority": "optional"
        },
        {
          "id": "discounts_entertainment",
          "title": "Set entertainment budget caps",
          "detail": "Use student plans without overspending.",
          "timing": "ongoing",
          "priority": "optional"
        }
      ]
    },
    {
      "id": "internet_tech",
      "title": "Internet & Tech",
      "subtitle": "Keep devices and access reliable",
      "categoryType": "internet",
      "icon": "wifi",
      "gradient": [
        "#4FACFE",
        "#00F2FE"
      ],
      "priority": "low",
      "urgency": "week1",
      "order": 13,
      "tasks": [
        {
          "id": "internet_broadband",
          "title": "Confirm home broadband",
          "detail": "Check speed, contract terms, and installation date.",
          "timing": "first_week",
          "priority": "must_do"
        },
        {
          "id": "internet_backup_data",
          "title": "Set mobile data backup",
          "detail": "Prepare hotspot fallback for study deadlines.",
          "timing": "first_week",
          "priority": "should_do"
        },
        {
          "id": "internet_security",
          "title": "Secure your devices",
          "detail": "Enable updates, password manager, and 2FA.",
          "timing": "first_month",
          "priority": "should_do"
        }
      ]
    },
    {
      "id": "social_networking",
      "title": "Social & Networking",
      "subtitle": "Build support and opportunities",
      "categoryType": "social",
      "icon": "person.3.fill",
      "gradient": [
        "#FFD3A5",
        "#FD6585"
      ],
      "priority": "low",
      "urgency": "anytime",
      "order": 14,
      "tasks": [
        {
          "id": "social_join_groups",
          "title": "Join student groups",
          "detail": "Find official course and international student communities.",
          "timing": "first_week",
          "priority": "should_do"
        },
        {
          "id": "social_attend_events",
          "title": "Attend welcome events",
          "detail": "Use early events to build your support network.",
          "timing": "first_month",
          "priority": "should_do"
        },
        {
          "id": "social_mentors",
          "title": "Connect with mentors",
          "detail": "Identify peer mentors for study and city guidance.",
          "timing": "first_month",
          "priority": "optional"
        },
        {
          "id": "social_boundaries",
          "title": "Set healthy social boundaries",
          "detail": "Balance academics, wellbeing, and social commitments.",
          "timing": "ongoing",
          "priority": "optional"
        }
      ]
    },
    {
      "id": "student_life",
      "title": "Student Life Essentials",
      "subtitle": "Build sustainable routines",
      "categoryType": "lifestyle",
      "icon": "backpack.fill",
      "gradient": [
        "#FFA8A8",
        "#FCFF00"
      ],
      "priority": "low",
      "urgency": "anytime",
      "order": 15,
      "tasks": [
        {
          "id": "life_weekly_planning",
          "title": "Set weekly planning routine",
          "detail": "Use one weekly review to plan study, work, and errands.",
          "timing": "ongoing",
          "priority": "should_do"
        },
        {
          "id": "life_health_habits",
          "title": "Track sleep and meal habits",
          "detail": "Create a sustainable routine for energy and focus.",
          "timing": "ongoing",
          "priority": "optional"
        },
        {
          "id": "life_financial_checkin",
          "title": "Monthly financial check-in",
          "detail": "Review budget drift and adjust spending targets.",
          "timing": "ongoing",
          "priority": "should_do"
        },
        {
          "id": "life_admin_cleanup",
          "title": "Monthly admin cleanup",
          "detail": "Organize digital files, receipts, and official emails.",
          "timing": "ongoing",
          "priority": "optional"
        },
        {
          "id": "life_personal_goals",
          "title": "Set personal learning goals",
          "detail": "Define skill-building goals outside coursework.",
          "timing": "ongoing",
          "priority": "optional"
        },
        {
          "id": "life_support_network",
          "title": "Maintain support check-ins",
          "detail": "Keep regular contact with trusted friends/family.",
          "timing": "ongoing",
          "priority": "optional"
        },
        {
          "id": "life_document_backups",
          "title": "Back up important documents",
          "detail": "Keep secure copies of IDs, banking, and study files.",
          "timing": "ongoing",
          "priority": "should_do"
        },
        {
          "id": "life_review_progress",
          "title": "Review progress each month",
          "detail": "Track completed tasks and identify next priorities.",
          "timing": "ongoing",
          "priority": "should_do"
        }
      ]
    }
  ]
}

```

## arrival uk/DesignSystem.swift

```swift
import SwiftUI
import UIKit
import os

struct CategoryPalette: Hashable {
    let start: Color
    let end: Color

    var fill: Color {
        start
    }

    var gradient: Color {
        start
    }

    var linearGradient: LinearGradient {
        LinearGradient(
            colors: [start, end],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var shadowColor: Color {
        start
    }
}

enum LayerZIndex {
    static let base: Double = 0
    static let stickyHeader: Double = 100
    static let overlayScrim: Double = 1000
    static let categoryOverlay: Double = 1050
    static let modal: Double = 1100
}

enum Theme {
    static let spaceXS: CGFloat = 4
    static let spaceS: CGFloat = 8
    static let spaceM: CGFloat = 12
    static let spaceL: CGFloat = 16
    static let spaceXL: CGFloat = 20
    static let spaceXXL: CGFloat = 24
    static let spaceXXXL: CGFloat = 32
    static let spaceHuge: CGFloat = 48

    static let radiusS: CGFloat = 8
    static let radiusM: CGFloat = 16
    static let radiusL: CGFloat = 24

    static let bottomBarReserve: CGFloat = 118

    // Home Theme Palette
    static let navy50 = color(0xEEF2FF)
    static let navy100 = color(0xE0E7FF)
    static let navy200 = color(0xC7D2FE)
    static let navy300 = color(0xA5B4FC)
    static let navy400 = color(0x818CF8)
    static let navy500 = color(0x6366F1)
    static let navy600 = color(0x4F46E5)
    static let navy700 = color(0x4338CA)
    static let navy800 = color(0x312E81)
    static let navy900 = color(0x1A1A2E)

    static let brandPrimary = color(0x5B7CFF)
    static let brandSecondary = color(0x7C3AED)
    static let primaryMain = brandPrimary
    static let primaryLight = color(0x7D95FF)
    static let primaryDark = brandSecondary

    static let beforeArrivalStart = color(0x667EEA)
    static let beforeArrivalEnd = color(0x764BA2)
    static let healthStart = color(0xF093FB)
    static let healthEnd = color(0xF5576C)
    static let moneyStart = color(0xFCCF31)
    static let moneyEnd = color(0xF55555)
    static let travelStart = color(0x4FACFE)
    static let travelEnd = color(0x00F2FE)

    static let reserveCategory5Start = color(0xA8EDEA)
    static let reserveCategory5End = color(0x6DD5FA)
    static let reserveCategory6Start = color(0xD299C2)
    static let reserveCategory6End = color(0xFEF9D7)
    static let reserveCategory7Start = color(0xFDCBF1)
    static let reserveCategory7End = color(0xE6DEE9)
    static let reserveCategory8Start = color(0xFFC371)
    static let reserveCategory8End = color(0xFF5F6D)

    static let terracotta50 = color(0xFDF5F3)
    static let terracotta100 = color(0xFAE6E0)
    static let terracotta200 = color(0xF5CCBD)
    static let terracotta300 = color(0xF0B39A)
    static let terracotta400 = color(0xEA9A77)
    static let terracotta500 = color(0xE07A5F)
    static let terracotta600 = color(0xD66849)
    static let terracotta700 = color(0xC25437)
    static let terracotta800 = color(0xA0442D)
    static let terracotta900 = color(0x7E3423)

    static let sage50 = color(0xF2F7F5)
    static let sage100 = color(0xE0EBE6)
    static let sage200 = color(0xC1D7CE)
    static let sage300 = color(0xA2C3B5)
    static let sage400 = color(0x92BBAA)
    static let sage500 = color(0x5CAE7F)
    static let sage600 = color(0x319795)
    static let sage700 = color(0x2C7A7B)
    static let sage800 = color(0x285E61)
    static let sage900 = color(0x234E52)

    static let warmOrange50 = color(0xFEF8F3)
    static let warmOrange100 = color(0xFDEEE0)
    static let warmOrange200 = color(0xFBDDC1)
    static let warmOrange300 = color(0xF8CCA2)
    static let warmOrange400 = color(0xF6B882)
    static let warmOrange500 = color(0xFFAB47)
    static let warmOrange600 = color(0xB7791F)
    static let warmOrange700 = color(0x975A16)
    static let warmOrange800 = color(0x744210)
    static let warmOrange900 = color(0x5F370E)

    static let cream50 = color(0xFFFFFF)
    static let cream100 = color(0xFFFFFF)
    static let cream200 = color(0xF8F9FF)
    static let cream300 = color(0xF1F3FF)
    static let cream400 = color(0xE5E7EB)
    static let cream500 = color(0xCBD5E1)

    // Warm luxury neutrals
    static let warmBase50 = color(0xFDFCFB)
    static let warmBase100 = color(0xFAF8F5)
    static let warmBase200 = color(0xF4F1EC)
    static let luxuryGold = color(0xF59E0B)
    static let luxuryGoldBorder = color(0xF59E0B, alpha: 0.20)

    static let gray50 = color(0xF8F9FA)
    static let gray100 = color(0xF1F3F5)
    static let gray200 = color(0xE9ECEF)
    static let gray300 = color(0xDEE2E6)
    static let gray400 = color(0xCED4DA)
    static let gray500 = color(0x94A3B8)
    static let gray600 = color(0x9CA3AF)
    static let gray700 = color(0x6B7280)
    static let gray800 = color(0x343A40)
    static let gray900 = color(0x212529)

    static let successLight = color(0xD4E7DD)
    static let successMain = color(0x22C55E)
    static let successDark = color(0x2F855A)
    static let warningLight = color(0xFDEEE0)
    static let warningMain = color(0xED8936)
    static let warningDark = color(0xC05621)
    static let errorLight = color(0xF8D7DA)
    static let errorMain = color(0xFC8181)
    static let errorDark = color(0xC53030)
    static let infoLight = color(0xD9E2EC)
    static let infoMain = color(0x4299E1)
    static let infoDark = color(0x2B6CB0)

    static let teal500 = color(0x38B2AC)
    static let purple500 = color(0x667EEA)
    static let amber500 = color(0xD69E2E)
    static let rose500 = color(0xFC8181)
    static let indigo500 = color(0x667EEA)
    static let olive500 = color(0x48BB78)
    static let coral500 = color(0xFC8181)
    static let sky500 = color(0x4299E1)

    // Home card specific colors
    static let moneyCardGradientStart = color(0xFFAB47)
    static let moneyCardGradientEnd = color(0xF08D42)
    static let travelCardGradientStart = color(0x4BC4D9)
    static let travelCardGradientEnd = color(0x5B92F6)
    static let workCardSolid = color(0x7B68EE)

    static let accent = brandPrimary
    static let accentSoft = primaryDark
    static let inverseText = color(0xFFFFFF)
    static let linkText = brandPrimary
    static let backgroundPrimary = warmBase100
    static let backgroundSecondary = color(0xFFFFFF)

    static let primaryText = color(0x1F2937)
    static let secondaryText = color(0x6B7280)
    static let tertiaryText = color(0x9CA3AF)

    static let brandGradient: Color = primaryMain

    static let track = color(0xEEF0F3)
    static let card = color(0xFFFFFF)
    static let stroke = color(0xEBEDF1)
    static let strokeStrong = color(0xD7DCE3)

    static let shadowSoft = Color.black.opacity(0.05)
    static let shadowMedium = Color.black.opacity(0.08)
    static let shadowElevated = Color.black.opacity(0.12)
    static let shadowCritical = navy900.opacity(0.15)
    static let modalScrim = Color.black.opacity(0.50)

    static let navBarBackground = color(0xFFFFFF)
    static let navActive = navy900
    static let navActiveBackground = navy50

    static let primaryButtonBackground = brandPrimary
    static let primaryButtonPressed = brandSecondary

    static func palette(for categoryID: String) -> CategoryPalette {
        if let known = legacyKnownCategoryGradient(forID: categoryID) {
            return known
        }
        return CategoryPalette(start: beforeArrivalStart, end: beforeArrivalEnd)
    }

    static func palette(for category: ChecklistCategory, among categories: [ChecklistCategory] = []) -> CategoryPalette {
        resolvedCategoryPalette(for: category, among: categories)
    }

    static func urgencyColor(_ urgency: CategoryUrgencyBand) -> Color {
        switch urgency {
        case .immediate:
            return color(0xD94F4F)
        case .week1:
            return warmOrange600
        case .week2:
            return navy500
        case .anytime:
            return warmOrange500
        case .completed:
            return successMain
        }
    }

    static func sourceTint(for sourceType: SourceTrustType) -> Color {
        switch sourceType {
        case .official:
            return navy900
        case .university:
            return sage700
        case .partner:
            return warmOrange700
        case .community:
            return terracotta700
        case .editorial:
            return navy700
        case .unknown:
            return gray700
        }
    }

    static func categoryBackground(for category: ChecklistCategory, among categories: [ChecklistCategory] = []) -> Color {
        palette(for: category, among: categories).fill
    }

    static func categoryText(for category: ChecklistCategory, among categories: [ChecklistCategory] = []) -> Color {
        categoryUsesDarkForeground(for: category, among: categories) ? navy900 : inverseText
    }

    static func categoryBadgeBackground(for category: ChecklistCategory, among categories: [ChecklistCategory] = []) -> Color {
        if category.urgencyBand == .completed {
            return successLight
        }

        switch category.visualPriority {
        case .critical:
            return terracotta500
        case .high:
            return cream200
        case .medium:
            return navy900
        case .low:
            return color(0xFFFFFF)
        }
    }

    static func categoryBadgeText(for category: ChecklistCategory, among categories: [ChecklistCategory] = []) -> Color {
        if category.urgencyBand == .completed {
            return successDark
        }

        switch category.visualPriority {
        case .critical, .medium:
            return inverseText
        case .high, .low:
            return navy900
        }
    }

    static func categoryUsesDarkForeground(for category: ChecklistCategory, among categories: [ChecklistCategory] = []) -> Bool {
        if let customHex = category.accentColorHex, let colorComponents = rgb(fromHexString: customHex) {
            return colorComponents.relativeLuminance > 0.72
        }

        let resolvedType = normalizedCategoryType(category.categoryType)
        if resolvedType == "shopping" {
            return true
        }

        return false
    }

    static func accentColor(for category: ChecklistCategory, among categories: [ChecklistCategory] = []) -> Color {
        categoryBackground(for: category, among: categories)
    }

    @ViewBuilder
    static func background(for scheme: ColorScheme, conservative: Bool) -> some View {
        if conservative {
            if scheme == .dark {
                navy900
            } else {
                backgroundPrimary
            }
        } else if scheme == .dark {
            LinearGradient(
                colors: [color(0x0B1020), color(0x121A2E), navy900],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            ZStack {
                LinearGradient(
                    colors: [warmBase50, warmBase100],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(navy500.opacity(0.05))
                    .frame(width: 620, height: 620)
                    .blur(radius: 140)
                    .offset(x: 220, y: -260)

                Circle()
                    .fill(luxuryGold.opacity(0.045))
                    .frame(width: 460, height: 460)
                    .blur(radius: 120)
                    .offset(x: -180, y: 280)

                Circle()
                    .fill(color(0xEC4899).opacity(0.035))
                    .frame(width: 360, height: 360)
                    .blur(radius: 110)
                    .offset(x: 170, y: 220)
            }
        }
    }

    private static func color(_ hex: UInt32, alpha: CGFloat = 1) -> Color {
        let red = CGFloat((hex >> 16) & 0xFF) / 255
        let green = CGFloat((hex >> 8) & 0xFF) / 255
        let blue = CGFloat(hex & 0xFF) / 255
        return Color(uiColor: UIColor(red: red, green: green, blue: blue, alpha: alpha))
    }

    private static func color(fromHexString value: String) -> Color? {
        let cleaned = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        guard cleaned.count == 6, let hex = UInt32(cleaned, radix: 16) else {
            return nil
        }

        return color(hex)
    }

    private static func canonicalCategoryID(_ rawID: String) -> String {
        rawID
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
    }

    private static func normalizedCategoryType(_ rawType: String?) -> String? {
        guard let rawType, !rawType.isEmpty else { return nil }
        return rawType
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
    }

    private static func typeColor(for category: ChecklistCategory) -> Color? {
        switch normalizedCategoryType(category.categoryType) {
        case "housing":
            return teal500
        case "academic":
            return purple500
        case "shopping":
            return amber500
        case "wellness":
            return rose500
        case "finance":
            return indigo500
        case "transport":
            return olive500
        case "social":
            return coral500
        case "travel":
            return sky500
        default:
            return nil
        }
    }

    private static func gradientPool() -> [CategoryPalette] {
        [
            CategoryPalette(start: beforeArrivalStart, end: beforeArrivalEnd),
            CategoryPalette(start: healthStart, end: healthEnd),
            CategoryPalette(start: moneyStart, end: moneyEnd),
            CategoryPalette(start: travelStart, end: travelEnd),
            CategoryPalette(start: reserveCategory5Start, end: reserveCategory5End),
            CategoryPalette(start: reserveCategory6Start, end: reserveCategory6End),
            CategoryPalette(start: reserveCategory7Start, end: reserveCategory7End),
            CategoryPalette(start: reserveCategory8Start, end: reserveCategory8End)
        ]
    }

    private static func colorPool(for priority: CategoryPriorityLevel) -> [CategoryPalette] {
        switch priority {
        case .critical:
            return [CategoryPalette(start: beforeArrivalStart, end: beforeArrivalEnd)]
        case .high:
            return [
                CategoryPalette(start: healthStart, end: healthEnd),
                CategoryPalette(start: reserveCategory6Start, end: reserveCategory6End)
            ]
        case .medium:
            return [
                CategoryPalette(start: moneyStart, end: moneyEnd),
                CategoryPalette(start: reserveCategory5Start, end: reserveCategory5End)
            ]
        case .low:
            return [
                CategoryPalette(start: travelStart, end: travelEnd),
                CategoryPalette(start: reserveCategory8Start, end: reserveCategory8End)
            ]
        }
    }

    private static func legacyKnownCategoryGradient(forID categoryID: String) -> CategoryPalette? {
        switch canonicalCategoryID(categoryID) {
        case "before_arrival", "getting_settled":
            return CategoryPalette(start: navy900, end: navy900)
        case "health_admin", "admin_legal":
            return CategoryPalette(start: sage500, end: sage500)
        case "work_career":
            return CategoryPalette(start: workCardSolid, end: workCardSolid)
        case "money_banking", "daily_living":
            return CategoryPalette(start: moneyCardGradientStart, end: moneyCardGradientEnd)
        case "travel_discounts":
            return CategoryPalette(start: travelCardGradientStart, end: travelCardGradientEnd)
        case "social":
            return CategoryPalette(start: reserveCategory8Start, end: reserveCategory8End)
        default:
            return nil
        }
    }

    private static func alternatingPriorityPalette(for category: ChecklistCategory, among categories: [ChecklistCategory]) -> CategoryPalette {
        let palette = colorPool(for: category.visualPriority)
        guard palette.count > 1 else { return palette.first ?? CategoryPalette(start: beforeArrivalStart, end: beforeArrivalEnd) }

        let samePriority = categories
            .filter { $0.visualPriority == category.visualPriority && $0.isVisible }
            .sorted { left, right in
                if left.order != right.order {
                    return (left.order ?? .max) < (right.order ?? .max)
                }
                return left.id < right.id
            }

        guard let index = samePriority.firstIndex(where: { $0.id == category.id }) else {
            return palette[0]
        }
        return palette[index % palette.count]
    }

    private static func resolvedCategoryPalette(for category: ChecklistCategory, among categories: [ChecklistCategory]) -> CategoryPalette {
        if let gradient = category.gradient, gradient.count >= 2 {
            let startHex = gradient[0]
            let endHex = gradient[1]
            if let startColor = color(fromHexString: startHex), let endColor = color(fromHexString: endHex) {
                return CategoryPalette(start: startColor, end: endColor)
            }
        }

        if let customHex = category.accentColorHex, let custom = color(fromHexString: customHex) {
            return CategoryPalette(start: custom, end: custom)
        }

        if let typedColor = typeColor(for: category) {
            return CategoryPalette(start: typedColor, end: typedColor)
        }

        if let known = legacyKnownCategoryGradient(forID: category.id) {
            return known
        }

        if !categories.isEmpty {
            return alternatingPriorityPalette(for: category, among: categories)
        }

        let pool = gradientPool()
        let stableIndex = abs(category.id.hashValue) % pool.count
        if pool.indices.contains(stableIndex) {
            return pool[stableIndex]
        }

        return CategoryPalette(start: beforeArrivalStart, end: beforeArrivalEnd)
    }

    private struct RGBColor {
        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat

        var relativeLuminance: CGFloat {
            (0.2126 * red) + (0.7152 * green) + (0.0722 * blue)
        }
    }

    private static func rgb(fromHexString value: String) -> RGBColor? {
        let cleaned = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        guard cleaned.count == 6, let hex = UInt32(cleaned, radix: 16) else {
            return nil
        }

        let red = CGFloat((hex >> 16) & 0xFF) / 255
        let green = CGFloat((hex >> 8) & 0xFF) / 255
        let blue = CGFloat(hex & 0xFF) / 255
        return RGBColor(red: red, green: green, blue: blue)
    }
}

struct CardChromeModifier: ViewModifier {
    let elevated: Bool

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Theme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Theme.stroke, lineWidth: 1)
            )
            .shadow(
                color: elevated ? Theme.shadowMedium : Theme.shadowSoft,
                radius: elevated ? 8 : 2,
                x: 0,
                y: elevated ? 4 : 1
            )
    }
}

struct GlassSheetPresentationModifier: ViewModifier {
    let conservative: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .presentationBackground(Theme.card)
        } else if conservative {
            content
                .presentationBackground(.thinMaterial)
        } else {
            content
                .presentationBackground(.regularMaterial)
        }
    }
}

extension View {
    func cardChrome(elevated: Bool) -> some View {
        modifier(CardChromeModifier(elevated: elevated))
    }

    func glassSheetPresentation(conservative: Bool) -> some View {
        modifier(GlassSheetPresentationModifier(conservative: conservative))
    }

    func staggeredEntry(index: Int, isActive: Bool, prefersReducedMotion: Bool) -> some View {
        modifier(
            StaggeredEntryModifier(
                index: index,
                isActive: isActive,
                prefersReducedMotion: prefersReducedMotion
            )
        )
    }
}

struct StaggeredEntryModifier: ViewModifier {
    let index: Int
    let isActive: Bool
    let prefersReducedMotion: Bool

    func body(content: Content) -> some View {
        let isVisible = isActive || prefersReducedMotion

        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 20)
            .scaleEffect(isVisible ? 1 : 0.98, anchor: .top)
            .animation(
                Motion.staggeredEntry(index: index, prefersReducedMotion: prefersReducedMotion),
                value: isActive
            )
    }
}

enum Motion {
    private static var systemPrefersReducedMotion: Bool {
        UIAccessibility.isReduceMotionEnabled || PerformanceProfile.prefersConservativeVisuals
    }

    @MainActor
    static func mutate(_ updates: () -> Void) {
        if systemPrefersReducedMotion {
            updates()
        } else {
            withAnimation(screenTransition(prefersReducedMotion: false)) {
                updates()
            }
        }
    }

    static func pressDown(prefersReducedMotion: Bool) -> Animation {
        if prefersReducedMotion {
            return .easeOut(duration: 0.06)
        }
        return .easeOut(duration: 0.10)
    }

    static func pressUp(prefersReducedMotion: Bool) -> Animation {
        if prefersReducedMotion {
            return .easeOut(duration: 0.12)
        }
        return .spring(response: 0.20, dampingFraction: 0.70)
    }

    static func launchEntrance(prefersReducedMotion: Bool) -> Animation {
        if prefersReducedMotion {
            return .easeOut(duration: 0.16)
        }
        return .spring(response: 0.40, dampingFraction: 0.75)
    }

    static func screenTransition(prefersReducedMotion: Bool) -> Animation {
        if prefersReducedMotion {
            return .easeInOut(duration: 0.18)
        }
        return .easeInOut(duration: 0.30)
    }

    static func modalAppear(prefersReducedMotion: Bool) -> Animation {
        if prefersReducedMotion {
            return .easeOut(duration: 0.16)
        }
        return .easeOut(duration: 0.30)
    }

    static func modalDismiss(prefersReducedMotion: Bool) -> Animation {
        if prefersReducedMotion {
            return .easeIn(duration: 0.14)
        }
        return .easeIn(duration: 0.20)
    }

    static func heroExpand(prefersReducedMotion: Bool) -> Animation {
        if prefersReducedMotion {
            return .easeInOut(duration: 0.20)
        }
        return .spring(response: 0.50, dampingFraction: 0.82)
    }

    static func heroCollapse(prefersReducedMotion: Bool) -> Animation {
        if prefersReducedMotion {
            return .easeInOut(duration: 0.18)
        }
        return .spring(response: 0.35, dampingFraction: 0.88)
    }

    static func heroReveal(prefersReducedMotion: Bool) -> Animation {
        if prefersReducedMotion {
            return .easeOut(duration: 0.16)
        }
        return .easeOut(duration: 0.30)
    }

    static func heroBackground(prefersReducedMotion: Bool) -> Animation {
        if prefersReducedMotion {
            return .easeInOut(duration: 0.14)
        }
        return .easeInOut(duration: 0.25)
    }

    static func staggeredEntry(index: Int, prefersReducedMotion: Bool) -> Animation {
        if prefersReducedMotion {
            return .easeOut(duration: 0.16)
        }
        let clampedIndex = max(0, min(index, 5))
        let delay = Double(clampedIndex) * 0.03
        return .easeOut(duration: 0.35).delay(delay)
    }
}

enum Haptics {
    private static let softGenerator = UIImpactFeedbackGenerator(style: .soft)
    private static let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private static let notificationGenerator = UINotificationFeedbackGenerator()

    static func softImpactIfAllowed() {
        guard !ProcessInfo.processInfo.isLowPowerModeEnabled else { return }
        softGenerator.prepare()
        softGenerator.impactOccurred(intensity: 0.8)
    }

    static func selectionIfAllowed() {
        guard !ProcessInfo.processInfo.isLowPowerModeEnabled else { return }
        lightGenerator.prepare()
        lightGenerator.impactOccurred(intensity: 0.6)
    }

    static func successIfAllowed() {
        guard !ProcessInfo.processInfo.isLowPowerModeEnabled else { return }
        notificationGenerator.prepare()
        notificationGenerator.notificationOccurred(.success)
    }
}

enum PerformanceProfile {
    private static let lowMemoryThresholdBytes: UInt64 = 6_000_000_000

    static var prefersConservativeVisuals: Bool {
        isSimulator || ProcessInfo.processInfo.isLowPowerModeEnabled || isLowMemoryClass || isThermallyConstrained
    }

    static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        false
        #endif
    }

    private static var isLowMemoryClass: Bool {
        ProcessInfo.processInfo.physicalMemory <= lowMemoryThresholdBytes
    }

    private static var isThermallyConstrained: Bool {
        ProcessInfo.processInfo.thermalState == .serious || ProcessInfo.processInfo.thermalState == .critical
    }
}

enum LaunchMetrics {
    private static let launchUptime = ProcessInfo.processInfo.systemUptime
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.arrivaluk.app",
        category: "startup"
    )
    private static let breadcrumbStorageKey = "launch.metrics.breadcrumbs.v1"
    private static let maxBreadcrumbCount = 80
    private static let breadcrumbQueue = DispatchQueue(label: "com.arrivaluk.launch-metrics")
    private static var breadcrumbCache: [String] = {
        guard let persisted = UserDefaults.standard.array(forKey: breadcrumbStorageKey) as? [String] else {
            return []
        }
        if persisted.count <= maxBreadcrumbCount {
            return persisted
        }
        return Array(persisted.suffix(maxBreadcrumbCount))
    }()
    private static let timestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static func mark(event: String) {
        let elapsed = ProcessInfo.processInfo.systemUptime - launchUptime
        let timestamp = timestampFormatter.string(from: Date())
        let breadcrumb = "\(timestamp) | +\(String(format: "%.3f", elapsed))s | \(event)"
        recordBreadcrumb(breadcrumb)

        #if DEBUG
        logger.debug("\(event, privacy: .public) +\(elapsed, format: .fixed(precision: 3))s")
        #endif
    }

    static func markStartupBudget(
        milestone: String,
        warningThresholdSeconds: TimeInterval
    ) {
        let elapsed = ProcessInfo.processInfo.systemUptime - launchUptime
        if elapsed > warningThresholdSeconds {
            mark(event: "startup_budget_exceeded_\(milestone)_\(String(format: "%.2f", elapsed))s")
            #if DEBUG
            logger.error(
                "startup budget exceeded at \(milestone, privacy: .public): \(elapsed, format: .fixed(precision: 3))s"
            )
            #endif
            return
        }

        #if DEBUG
        logger.debug(
            "startup budget met at \(milestone, privacy: .public): \(elapsed, format: .fixed(precision: 3))s"
        )
        #endif
    }

    static func recentBreadcrumbs() -> [String] {
        breadcrumbQueue.sync {
            breadcrumbCache
        }
    }

    static func clearBreadcrumbs() {
        breadcrumbQueue.sync {
            breadcrumbCache.removeAll(keepingCapacity: true)
            UserDefaults.standard.removeObject(forKey: breadcrumbStorageKey)
        }
    }

    private static func recordBreadcrumb(_ breadcrumb: String) {
        breadcrumbQueue.sync {
            breadcrumbCache.append(breadcrumb)
            if breadcrumbCache.count > maxBreadcrumbCount {
                breadcrumbCache.removeFirst(breadcrumbCache.count - maxBreadcrumbCount)
            }
            UserDefaults.standard.set(breadcrumbCache, forKey: breadcrumbStorageKey)
        }
    }
}

```

## arrival uk/Features/Notifications/NotificationManager.swift

```swift
import Foundation
import UserNotifications

/// Handles local reminder scheduling for checklist tasks.
/// Requires iOS 17.0+
@available(iOS 17.0, *)
final class NotificationManager {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()
    private let calendar = Calendar.current
    private let reminderHour = 9
    private let reminderMinute = 0
    private let reminderPrefix = "task-reminder-"

    private init() {}

    func requestPermissionIfNeeded(promptIfUndetermined: Bool = true) async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            guard promptIfUndetermined else { return false }
            do {
                return try await center.requestAuthorization(options: [.alert, .badge, .sound])
            } catch {
                CrashReporter.record(
                    error: error,
                    context: "notification_permission_request"
                )
                return false
            }
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    func refreshTaskReminders(
        categories: [ChecklistCategory],
        arrivalDate: Date
    ) async {
        let isAuthorized = await requestPermissionIfNeeded(promptIfUndetermined: false)
        guard isAuthorized else { return }

        await removeAllTaskReminderRequests()

        let tasks = categories.flatMap(\.tasks).filter { !$0.isComplete }
        for task in tasks {
            guard let fireDate = reminderDate(for: task, arrivalDate: arrivalDate),
                  fireDate > Date() else {
                continue
            }

            let content = UNMutableNotificationContent()
            content.title = task.priority == .mustDo ? "Important task reminder" : "Task reminder"
            content.body = task.title
            content.sound = .default
            content.userInfo = [
                "taskID": task.id
            ]

            let dateComponents = calendar.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: fireDate
            )
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: dateComponents,
                repeats: false
            )
            let request = UNNotificationRequest(
                identifier: reminderID(for: task.id),
                content: content,
                trigger: trigger
            )
            do {
                try await center.add(request)
            } catch {
                CrashReporter.record(
                    error: error,
                    context: "notification_schedule",
                    metadata: ["task_id": task.id]
                )
            }
        }
    }

    func cancelReminder(forTaskID taskID: String) {
        center.removePendingNotificationRequests(withIdentifiers: [reminderID(for: taskID)])
    }

    func cancelAllReminders() {
        Task { await removeAllTaskReminderRequests() }
    }

    private func removeAllTaskReminderRequests() async {
        let pending = await center.pendingNotificationRequests()
        let identifiers = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(reminderPrefix) }
        guard !identifiers.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    private func reminderID(for taskID: String) -> String {
        "\(reminderPrefix)\(taskID)"
    }

    private func reminderDate(for task: ChecklistTask, arrivalDate: Date) -> Date? {
        let arrivalStart = calendar.startOfDay(for: arrivalDate)
        let scheduledDay: Date?

        switch task.timing {
        case .monthBeforeArrival:
            scheduledDay = calendar.date(byAdding: .day, value: -30, to: arrivalStart)
        case .weekBeforeArrival:
            scheduledDay = calendar.date(byAdding: .day, value: -7, to: arrivalStart)
        case .firstWeek:
            scheduledDay = calendar.date(byAdding: .day, value: 1, to: arrivalStart)
        case .firstMonth:
            scheduledDay = calendar.date(byAdding: .day, value: 7, to: arrivalStart)
        case .ongoing, .anytime:
            scheduledDay = nil
        }

        guard let day = scheduledDay else { return nil }

        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.hour = reminderHour
        components.minute = reminderMinute
        return calendar.date(from: components)
    }
}

```

## arrival uk/Features/Notifications/PushNotificationManager.swift

```swift
import Foundation
import UserNotifications
import Combine

#if canImport(UIKit)
import UIKit
#endif

#if canImport(FirebaseMessaging) && canImport(FirebaseFunctions)
import FirebaseMessaging
import FirebaseFunctions

@available(iOS 17.0, *)
@MainActor
final class PushNotificationManager: NSObject, ObservableObject {
    static let shared = PushNotificationManager()

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var fcmToken: String?

    private let functions = Functions.functions()

    private override init() {
        super.init()
    }

    func configureIfNeeded() {
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        Task { await refreshAuthorizationStatus() }
    }

    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    func requestPermissionIfNeeded() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        if settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional {
            authorizationStatus = settings.authorizationStatus
            return true
        }

        guard settings.authorizationStatus == .notDetermined else {
            authorizationStatus = settings.authorizationStatus
            return false
        }

        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]
            )
            await refreshAuthorizationStatus()
            #if canImport(UIKit)
            if granted {
                UIApplication.shared.registerForRemoteNotifications()
            }
            #endif
            return granted
        } catch {
            CrashReporter.record(error: error, context: "push_permission_request")
            return false
        }
    }

    func registerDeviceTokenWithBackend(_ token: String) async {
        do {
            _ = try await functions.httpsCallable("registerDeviceToken").call([
                "fcmToken": token,
                "platform": "ios",
            ])
        } catch {
            CrashReporter.record(error: error, context: "push_register_device_token")
        }
    }

    func unregisterDeviceTokenFromBackend() async {
        do {
            _ = try await functions.httpsCallable("unregisterDeviceToken").call([:])
        } catch {
            CrashReporter.record(error: error, context: "push_unregister_device_token")
        }
    }
}

@available(iOS 17.0, *)
extension PushNotificationManager: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .badge, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        await MainActor.run {
            NotificationCenter.default.post(
                name: .didTapRemoteNotification,
                object: nil,
                userInfo: userInfo
            )
        }
    }
}

@available(iOS 17.0, *)
extension PushNotificationManager: MessagingDelegate {
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }

        Task { @MainActor in
            self.fcmToken = token
            await self.registerDeviceTokenWithBackend(token)
        }
    }
}

#else

@available(iOS 17.0, *)
@MainActor
final class PushNotificationManager: ObservableObject {
    static let shared = PushNotificationManager()

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var fcmToken: String?

    private init() {}

    func configureIfNeeded() {}
    func refreshAuthorizationStatus() async {}
    func requestPermissionIfNeeded() async -> Bool { false }
    func registerDeviceTokenWithBackend(_ token: String) async {}
    func unregisterDeviceTokenFromBackend() async {}
}

#endif

extension Notification.Name {
    static let didTapRemoteNotification = Notification.Name("didTapRemoteNotification")
}

```

## arrival uk/Features/Safety/EmergencyContactsSheet.swift

```swift
import SwiftUI
import UIKit

@available(iOS 17.0, *)
struct EmergencyContactItem: Identifiable {
    let id: String
    let name: String
    let number: String
    let detail: String
    let symbol: String
    let tint: Color
    let emergency: Bool
}

@available(iOS 17.0, *)
struct EmergencyContactsSheet: View {
    var onClose: (() -> Void)? = nil

    private let contacts: [EmergencyContactItem] = [
        EmergencyContactItem(
            id: "999",
            name: "Emergency Services",
            number: "999",
            detail: "Police, Fire, Ambulance",
            symbol: "exclamationmark.triangle.fill",
            tint: .red,
            emergency: true
        ),
        EmergencyContactItem(
            id: "111",
            name: "NHS Non-Emergency",
            number: "111",
            detail: "24/7 urgent medical advice",
            symbol: "cross.case.fill",
            tint: .blue,
            emergency: false
        ),
        EmergencyContactItem(
            id: "101",
            name: "Police Non-Emergency",
            number: "101",
            detail: "Report non-urgent incidents",
            symbol: "shield.fill",
            tint: .indigo,
            emergency: false
        ),
        EmergencyContactItem(
            id: "116123",
            name: "Samaritans",
            number: "116123",
            detail: "Emotional support and crisis line",
            symbol: "heart.fill",
            tint: .green,
            emergency: false
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Theme.spaceS) {
                Text("Emergency Contacts")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.primaryText)
                Spacer()
                Button("Done") { close() }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.linkText)
                    .buttonStyle(.plain)
            }
            .padding(.horizontal, Theme.spaceXL)
            .padding(.top, Theme.spaceM)
            .padding(.bottom, Theme.spaceS)

            Divider()
                .overlay(Theme.stroke)

            List {
                Section {
                    Text("For life-threatening emergencies, call 999 immediately.")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryText)
                        .padding(.vertical, 4)
                }

                let emergencyContacts = contacts.filter(\.emergency)
                if !emergencyContacts.isEmpty {
                    Section("Emergency") {
                        ForEach(emergencyContacts) { contact in
                            contactRow(contact)
                        }
                    }
                }

                let supportContacts = contacts.filter { !$0.emergency }
                if !supportContacts.isEmpty {
                    Section("Support") {
                        ForEach(supportContacts) { contact in
                            contactRow(contact)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.card)
        }
        .background(Theme.card)
    }

    @ViewBuilder
    private func contactRow(_ contact: EmergencyContactItem) -> some View {
        Button {
            call(number: contact.number)
        } label: {
            HStack(spacing: Theme.spaceS) {
                Image(systemName: contact.symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(
                        Circle()
                            .fill(contact.tint)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(contact.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.primaryText)
                    Text("\(contact.number) • \(contact.detail)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.secondaryText)
                }

                Spacer(minLength: Theme.spaceXS)

                Image(systemName: "phone.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(contact.tint)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private func call(number: String) {
        guard let url = URL(string: "tel://\(number)"),
              UIApplication.shared.canOpenURL(url) else {
            return
        }
        UIApplication.shared.open(url)
    }

    private func close() {
        onClose?()
    }
}

```

## arrival uk/Features/Search/TaskSearchSheet.swift

```swift
import SwiftUI

@available(iOS 17.0, *)
struct TaskSearchResult: Identifiable, Hashable {
    let id: String
    let categoryID: String
    let categoryTitle: String
    let task: ChecklistTask

    init(categoryID: String, categoryTitle: String, task: ChecklistTask) {
        self.id = "\(categoryID)::\(task.id)"
        self.categoryID = categoryID
        self.categoryTitle = categoryTitle
        self.task = task
    }
}

@available(iOS 17.0, *)
struct TaskSearchSheet: View {
    let categories: [ChecklistCategory]
    let city: String
    let university: String
    var onSelectTask: (ChecklistTask) -> Void
    var onClose: (() -> Void)? = nil

    @State private var query = ""

    private var results: [TaskSearchResult] {
        let visibleCategories = categories.filter {
            $0.isVisible && !$0.tasks.isEmpty && $0.matchesAudience(city: city, university: university)
        }

        let normalizedQuery = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !normalizedQuery.isEmpty else { return [] }

        return visibleCategories.flatMap { category in
            category.tasks.compactMap { task in
                let haystack: [String] = [
                    task.title,
                    task.detail ?? "",
                    task.sourceTitle ?? ""
                ]
                .map { $0.lowercased() }

                guard haystack.contains(where: { $0.contains(normalizedQuery) }) else {
                    return nil
                }

                return TaskSearchResult(
                    categoryID: category.id,
                    categoryTitle: category.title,
                    task: task
                )
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Theme.spaceS) {
                Text("Search Tasks")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.primaryText)
                Spacer()
                Button("Done") { close() }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.linkText)
                    .buttonStyle(.plain)
            }
            .padding(.horizontal, Theme.spaceXL)
            .padding(.top, Theme.spaceM)
            .padding(.bottom, Theme.spaceS)

            Divider()
                .overlay(Theme.stroke)

            VStack(spacing: Theme.spaceM) {
                HStack(spacing: Theme.spaceS) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Theme.tertiaryText)
                    TextField("Search by task, details, source…", text: $query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)

                    if !query.isEmpty {
                        Button {
                            query = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Theme.tertiaryText)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Theme.spaceM)
                .padding(.vertical, Theme.spaceS)
                .background(
                    RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous)
                        .fill(Theme.gray50)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous)
                        .stroke(Theme.stroke, lineWidth: 1)
                )

                if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    placeholder(
                        icon: "magnifyingglass",
                        title: "Search for a task",
                        message: "Type any keyword like visa, GP, railcard, bank, or council tax."
                    )
                } else if results.isEmpty {
                    placeholder(
                        icon: "exclamationmark.magnifyingglass",
                        title: "No results",
                        message: "Try a broader keyword."
                    )
                } else {
                    List(results) { result in
                        Button {
                            onSelectTask(result.task)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(result.task.title)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Theme.primaryText)
                                Text(result.categoryTitle)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Theme.secondaryText)
                                if let detail = result.task.detail, !detail.isEmpty {
                                    Text(detail)
                                        .font(.system(size: 12, weight: .regular))
                                        .foregroundStyle(Theme.tertiaryText)
                                        .lineLimit(2)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Theme.card)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Theme.card)
                }
            }
            .padding(.horizontal, Theme.spaceXL)
            .padding(.top, Theme.spaceM)
            .background(Theme.card)
        }
        .background(Theme.card)
    }

    @ViewBuilder
    private func placeholder(icon: String, title: String, message: String) -> some View {
        VStack(spacing: Theme.spaceS) {
            Image(systemName: icon)
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(Theme.tertiaryText)
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.primaryText)
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, Theme.spaceXL)
    }

    private func close() {
        onClose?()
    }
}

```

## arrival uk/Models.swift

```swift
import Foundation

struct ChecklistStats {
    let totalTasks: Int
    let completedTasks: Int

    var overallProgress: Double {
        guard totalTasks > 0 else { return 0 }
        return Double(completedTasks) / Double(totalTasks)
    }

    init(categories: [ChecklistCategory]) {
        var total = 0
        var completed = 0

        for category in categories {
            total += category.tasks.count
            completed += category.tasks.reduce(0) { partialResult, task in
                partialResult + (task.isComplete ? 1 : 0)
            }
        }

        self.totalTasks = total
        self.completedTasks = completed
    }
}

struct CategoryStats {
    let totalCount: Int
    let completedCount: Int

    var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    init(tasks: [ChecklistTask]) {
        self.totalCount = tasks.count
        self.completedCount = tasks.reduce(0) { partialResult, task in
            partialResult + (task.isComplete ? 1 : 0)
        }
    }
}

enum TaskTiming: String, Codable, Hashable {
    case monthBeforeArrival = "month_before_arrival"
    case weekBeforeArrival = "week_before_arrival"
    case firstWeek = "first_week"
    case firstMonth = "first_month"
    case ongoing = "ongoing"
    case anytime = "anytime"

    var label: String {
        switch self {
        case .monthBeforeArrival:
            return "About a month before"
        case .weekBeforeArrival:
            return "About a week before"
        case .firstWeek:
            return "First week"
        case .firstMonth:
            return "First month"
        case .ongoing:
            return "Ongoing"
        case .anytime:
            return "Anytime"
        }
    }
}

enum TaskPriority: String, Codable, Hashable {
    case mustDo = "must_do"
    case shouldDo = "should_do"
    case optional = "optional"

    var label: String {
        switch self {
        case .mustDo:
            return "Must do"
        case .shouldDo:
            return "Should do"
        case .optional:
            return "Optional"
        }
    }
}

enum TaskUrgency: String, Codable, Hashable {
    case high
    case medium
    case low

    var label: String {
        switch self {
        case .high:
            return "High urgency"
        case .medium:
            return "Medium urgency"
        case .low:
            return "Low urgency"
        }
    }
}

enum TaskContentType: String, Codable, Hashable {
    case richGuide = "rich-guide"
    case comparisonGuide = "comparison-guide"
    case processGuide = "process-guide"
    case simpleText = "simple-text"
}

struct TaskContent: Hashable, Codable {
    var type: TaskContentType
    var sections: [ContentSection]

    init(type: TaskContentType = .simpleText, sections: [ContentSection] = []) {
        self.type = type
        self.sections = sections
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case sections
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decodeIfPresent(TaskContentType.self, forKey: .type) ?? .simpleText
        self.sections = try container.decodeIfPresent([ContentSection].self, forKey: .sections) ?? []
    }
}

enum ContentSection: Hashable, Codable {
    case why(WhySectionData)
    case overview(OverviewSectionData)
    case checklist(ChecklistSectionData)
    case options(OptionsSectionData)
    case comparisonTable(OptionsSectionData)
    case tips(TipsSectionData)
    case references(ReferencesSectionData)
    case officialReferences(OfficialReferencesSectionData)
    case steps(StepsSectionData)
    case apps(AppsSectionData)
    case faqs(FAQSectionData)
    case unsupported(UnsupportedSectionData)

    private enum TypeKey: String, CodingKey {
        case type
        case title
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: TypeKey.self)
        let typeRaw = try container.decode(String.self, forKey: .type)

        switch typeRaw {
        case "why":
            self = .why(try WhySectionData(from: decoder))
        case "overview":
            self = .overview(try OverviewSectionData(from: decoder))
        case "checklist":
            self = .checklist(try ChecklistSectionData(from: decoder))
        case "options":
            self = .options(try OptionsSectionData(from: decoder))
        case "comparison-table":
            self = .comparisonTable(try OptionsSectionData(from: decoder))
        case "tips":
            self = .tips(try TipsSectionData(from: decoder))
        case "references":
            self = .references(try ReferencesSectionData(from: decoder))
        case "official-references":
            self = .officialReferences(try OfficialReferencesSectionData(from: decoder))
        case "steps":
            self = .steps(try StepsSectionData(from: decoder))
        case "apps":
            self = .apps(try AppsSectionData(from: decoder))
        case "faqs":
            self = .faqs(try FAQSectionData(from: decoder))
        default:
            let title = try container.decodeIfPresent(String.self, forKey: .title)
            let rawPayload = try? JSONValue(from: decoder)
            self = .unsupported(
                UnsupportedSectionData(
                    type: typeRaw,
                    title: title,
                    payload: UnsupportedSectionData.extractPayload(from: rawPayload)
                )
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .why(let value):
            try value.encode(to: encoder)
        case .overview(let value):
            try value.encode(to: encoder)
        case .checklist(let value):
            try value.encode(to: encoder)
        case .options(let value):
            try value.encode(to: encoder)
        case .comparisonTable(let value):
            var adapted = value
            adapted.type = "comparison-table"
            try adapted.encode(to: encoder)
        case .tips(let value):
            try value.encode(to: encoder)
        case .references(let value):
            try value.encode(to: encoder)
        case .officialReferences(let value):
            try value.encode(to: encoder)
        case .steps(let value):
            try value.encode(to: encoder)
        case .apps(let value):
            try value.encode(to: encoder)
        case .faqs(let value):
            try value.encode(to: encoder)
        case .unsupported(let value):
            try value.encode(to: encoder)
        }
    }
}

struct WhySectionData: Hashable, Codable {
    var type: String = "why"
    var title: String?
    var description: String?
    var content: String
    var icon: String?
}

struct OverviewSectionData: Hashable, Codable {
    var type: String = "overview"
    var title: String?
    var description: String?
    var content: String
}

struct ChecklistSectionData: Hashable, Codable {
    var type: String = "checklist"
    var title: String?
    var description: String?
    var items: [String]
    var allowUserChecks: Bool?
}

struct OptionsSectionData: Hashable, Codable {
    var type: String = "options"
    var title: String?
    var description: String?
    var items: [OptionItem]
}

enum SourceTrustType: String, Codable, Hashable {
    case official
    case university
    case partner
    case community
    case editorial
    case unknown

    var label: String {
        switch self {
        case .official:
            return "Official"
        case .university:
            return "University"
        case .partner:
            return "Partner"
        case .community:
            return "Community"
        case .editorial:
            return "Editorial"
        case .unknown:
            return "Unverified"
        }
    }
}

struct AudienceFilters: Hashable, Codable {
    var cities: [String] = []
    var universities: [String] = []

    var isEmpty: Bool {
        cities.isEmpty && universities.isEmpty
    }

    func matches(city: String, university: String) -> Bool {
        let normalizedCity = Self.normalize(city)
        let normalizedUniversity = Self.normalize(university)

        let cityMatch: Bool
        if cities.isEmpty || normalizedCity.isEmpty {
            cityMatch = true
        } else {
            cityMatch = cities.contains { Self.matchesFilter($0, query: normalizedCity) }
        }

        let universityMatch: Bool
        if universities.isEmpty || normalizedUniversity.isEmpty {
            universityMatch = true
        } else {
            universityMatch = universities.contains { Self.matchesFilter($0, query: normalizedUniversity) }
        }

        return cityMatch && universityMatch
    }

    private static func matchesFilter(_ rawFilter: String, query: String) -> Bool {
        let filter = normalize(rawFilter)
        guard !filter.isEmpty else { return true }
        if filter == "*" || filter == "all" {
            return true
        }
        return query.contains(filter) || filter.contains(query)
    }

    private static func normalize(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
    }
}

struct SourceMetadata: Hashable, Codable {
    var sourceType: SourceTrustType?
    var sourceName: String?
    var lastVerified: String?
    var audience: AudienceFilters?
    var note: String?

    var resolvedTrustType: SourceTrustType {
        sourceType ?? .unknown
    }

    var verifiedLabel: String? {
        guard let lastVerified, !lastVerified.isEmpty else { return nil }
        if let date = Self.isoFormatter.date(from: lastVerified) ?? Self.fallbackFormatter.date(from: lastVerified) {
            return Self.outputFormatter.string(from: date)
        }
        return lastVerified
    }

    func matchesAudience(city: String, university: String) -> Bool {
        guard let audience else { return true }
        return audience.matches(city: city, university: university)
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter
    }()

    private static let fallbackFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let outputFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}

struct OptionItem: Hashable, Codable {
    var name: String
    var description: String?
    var rating: Double?
    var tags: [String] = []
    var priceLevel: String?
    var link: LinkData?
    var location: LocationData?
    var highlights: [String] = []
    var source: SourceMetadata?
    var audience: AudienceFilters?

    private enum CodingKeys: String, CodingKey {
        case name
        case description
        case rating
        case tags
        case priceLevel
        case link
        case location
        case highlights
        case source
        case audience
    }

    init(
        name: String,
        description: String? = nil,
        rating: Double? = nil,
        tags: [String] = [],
        priceLevel: String? = nil,
        link: LinkData? = nil,
        location: LocationData? = nil,
        highlights: [String] = [],
        source: SourceMetadata? = nil,
        audience: AudienceFilters? = nil
    ) {
        self.name = name
        self.description = description
        self.rating = rating
        self.tags = tags
        self.priceLevel = priceLevel
        self.link = link
        self.location = location
        self.highlights = highlights
        self.source = source
        self.audience = audience
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
        self.rating = try container.decodeIfPresent(Double.self, forKey: .rating)
        self.tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        self.priceLevel = try container.decodeIfPresent(String.self, forKey: .priceLevel)
        self.link = try container.decodeIfPresent(LinkData.self, forKey: .link)
        self.location = try container.decodeIfPresent(LocationData.self, forKey: .location)
        self.highlights = try container.decodeIfPresent([String].self, forKey: .highlights) ?? []
        self.source = try container.decodeIfPresent(SourceMetadata.self, forKey: .source)
        self.audience = try container.decodeIfPresent(AudienceFilters.self, forKey: .audience)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(rating, forKey: .rating)
        try container.encode(tags, forKey: .tags)
        try container.encodeIfPresent(priceLevel, forKey: .priceLevel)
        try container.encodeIfPresent(link, forKey: .link)
        try container.encodeIfPresent(location, forKey: .location)
        try container.encode(highlights, forKey: .highlights)
        try container.encodeIfPresent(source, forKey: .source)
        try container.encodeIfPresent(audience, forKey: .audience)
    }

    func matchesAudience(city: String, university: String) -> Bool {
        let directAudienceMatch = audience?.matches(city: city, university: university) ?? true
        let sourceAudienceMatch = source?.matchesAudience(city: city, university: university) ?? true
        return directAudienceMatch && sourceAudienceMatch
    }
}

struct TipsSectionData: Hashable, Codable {
    var type: String = "tips"
    var title: String?
    var description: String?
    var items: [TipItem]
}

struct TipItem: Hashable, Codable {
    var text: String
    var author: String?
    var upvotes: Int?
}

struct ReferencesSectionData: Hashable, Codable {
    var type: String = "references"
    var title: String?
    var description: String?
    var items: [ReferenceItem]
}

struct OfficialReferencesSectionData: Hashable, Codable {
    var type: String = "official-references"
    var title: String?
    var description: String?
    var items: [ReferenceItem]
}

struct ReferenceItem: Hashable, Codable {
    var title: String
    var description: String?
    var url: String
    var type: String?
    var icon: String?
    var organization: String?
    var source: SourceMetadata?
    var audience: AudienceFilters?

    var resolvedSourceMetadata: SourceMetadata? {
        if let source {
            return source
        }

        if let type, type.lowercased() == "official" {
            return SourceMetadata(
                sourceType: .official,
                sourceName: organization,
                lastVerified: nil,
                audience: audience,
                note: nil
            )
        }

        if let organization, !organization.isEmpty {
            return SourceMetadata(
                sourceType: .editorial,
                sourceName: organization,
                lastVerified: nil,
                audience: audience,
                note: nil
            )
        }

        return nil
    }

    func matchesAudience(city: String, university: String) -> Bool {
        let directAudienceMatch = audience?.matches(city: city, university: university) ?? true
        let sourceAudienceMatch = resolvedSourceMetadata?.matchesAudience(city: city, university: university) ?? true
        return directAudienceMatch && sourceAudienceMatch
    }
}

struct StepsSectionData: Hashable, Codable {
    var type: String = "steps"
    var title: String?
    var description: String?
    var items: [ProcessStepItem]
}

struct ProcessStepItem: Hashable, Codable {
    var number: Int
    var title: String
    var duration: String?
    var cost: String?
    var description: String?
    var actions: [StepAction] = []
    var requirements: [String] = []
    var tips: [String] = []

    private enum CodingKeys: String, CodingKey {
        case number
        case title
        case duration
        case cost
        case description
        case actions
        case requirements
        case tips
    }

    init(
        number: Int,
        title: String,
        duration: String? = nil,
        cost: String? = nil,
        description: String? = nil,
        actions: [StepAction] = [],
        requirements: [String] = [],
        tips: [String] = []
    ) {
        self.number = number
        self.title = title
        self.duration = duration
        self.cost = cost
        self.description = description
        self.actions = actions
        self.requirements = requirements
        self.tips = tips
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.number = try container.decode(Int.self, forKey: .number)
        self.title = try container.decode(String.self, forKey: .title)
        self.duration = try container.decodeIfPresent(String.self, forKey: .duration)
        self.cost = try container.decodeIfPresent(String.self, forKey: .cost)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
        self.actions = try container.decodeIfPresent([StepAction].self, forKey: .actions) ?? []
        self.requirements = try container.decodeIfPresent([String].self, forKey: .requirements) ?? []
        self.tips = try container.decodeIfPresent([String].self, forKey: .tips) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(number, forKey: .number)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(duration, forKey: .duration)
        try container.encodeIfPresent(cost, forKey: .cost)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encode(actions, forKey: .actions)
        try container.encode(requirements, forKey: .requirements)
        try container.encode(tips, forKey: .tips)
    }
}

struct StepAction: Hashable, Codable {
    var type: String
    var label: String
    var url: String?
    var icon: String?
    var name: String?
    var cost: String?
    var searchTerm: String?
    var source: SourceMetadata?

    var resolvedURL: URL? {
        if let url, let parsed = URL(string: url) {
            return parsed
        }

        if let searchTerm, !searchTerm.isEmpty {
            let query = searchTerm.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? searchTerm
            return URL(string: "https://maps.apple.com/?q=\(query)")
        }

        return nil
    }
}

struct AppsSectionData: Hashable, Codable {
    var type: String = "apps"
    var title: String?
    var description: String?
    var items: [AppRecommendationItem]
}

struct AppRecommendationItem: Hashable, Codable {
    var name: String
    var description: String?
    var icon: String?
    var downloadLinks: AppDownloadLinks?
}

struct AppDownloadLinks: Hashable, Codable {
    var ios: String?
    var android: String?

    var iosURL: URL? {
        guard let ios, !ios.isEmpty else { return nil }
        return URL(string: ios)
    }

    var androidURL: URL? {
        guard let android, !android.isEmpty else { return nil }
        return URL(string: android)
    }

    var primaryURL: URL? {
        iosURL ?? androidURL
    }
}

struct FAQSectionData: Hashable, Codable {
    var type: String = "faqs"
    var title: String?
    var description: String?
    var items: [FAQItem]
}

struct FAQItem: Hashable, Codable {
    var question: String
    var answer: String
}

struct LinkData: Hashable, Codable {
    var type: String
    var url: String
    var label: String?
    var tracking: String?
    var source: SourceMetadata?
    var audience: AudienceFilters?

    var resolvedURL: URL? {
        URL(string: url)
    }

    func matchesAudience(city: String, university: String) -> Bool {
        let directAudienceMatch = audience?.matches(city: city, university: university) ?? true
        let sourceAudienceMatch = source?.matchesAudience(city: city, university: university) ?? true
        return directAudienceMatch && sourceAudienceMatch
    }
}

struct LocationData: Hashable, Codable {
    var type: String
    var search: String?
    var coordinates: Coordinates?
    var address: String?

    struct Coordinates: Hashable, Codable {
        var lat: Double
        var lng: Double
    }

    var mapsURL: URL? {
        if let search, !search.isEmpty {
            let query = search.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? search
            return URL(string: "https://maps.apple.com/?q=\(query)")
        }

        if let coordinates {
            return URL(string: "https://maps.apple.com/?ll=\(coordinates.lat),\(coordinates.lng)")
        }

        if let address, !address.isEmpty {
            let query = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? address
            return URL(string: "https://maps.apple.com/?q=\(query)")
        }

        return nil
    }
}

struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}

enum JSONValue: Hashable, Codable {
    case object([String: JSONValue])
    case array([JSONValue])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        if let keyedContainer = try? decoder.container(keyedBy: DynamicCodingKey.self) {
            var object: [String: JSONValue] = [:]
            for key in keyedContainer.allKeys {
                object[key.stringValue] = try keyedContainer.decode(JSONValue.self, forKey: key)
            }
            self = .object(object)
            return
        }

        if var unkeyedContainer = try? decoder.unkeyedContainer() {
            var array: [JSONValue] = []
            while !unkeyedContainer.isAtEnd {
                array.append(try unkeyedContainer.decode(JSONValue.self))
            }
            self = .array(array)
            return
        }

        let singleContainer = try decoder.singleValueContainer()
        if singleContainer.decodeNil() {
            self = .null
        } else if let boolValue = try? singleContainer.decode(Bool.self) {
            self = .bool(boolValue)
        } else if let numberValue = try? singleContainer.decode(Double.self) {
            self = .number(numberValue)
        } else if let stringValue = try? singleContainer.decode(String.self) {
            self = .string(stringValue)
        } else {
            throw DecodingError.dataCorruptedError(
                in: singleContainer,
                debugDescription: "Unsupported JSON payload"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .object(let value):
            var container = encoder.container(keyedBy: DynamicCodingKey.self)
            for (key, payload) in value {
                guard let codingKey = DynamicCodingKey(stringValue: key) else { continue }
                try container.encode(payload, forKey: codingKey)
            }
        case .array(let value):
            var container = encoder.unkeyedContainer()
            for payload in value {
                try container.encode(payload)
            }
        case .string(let value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case .number(let value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case .bool(let value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case .null:
            var container = encoder.singleValueContainer()
            try container.encodeNil()
        }
    }
}

struct UnsupportedSectionData: Hashable, Codable {
    var type: String
    var title: String?
    var payload: JSONValue?

    private enum CodingKeys: String, CodingKey {
        case type
        case title
    }

    init(type: String, title: String?, payload: JSONValue? = nil) {
        self.type = type
        self.title = title
        self.payload = payload
    }

    static func extractPayload(from rawValue: JSONValue?) -> JSONValue? {
        guard case .object(let rawObject) = rawValue else { return nil }
        var filtered = rawObject
        filtered.removeValue(forKey: "type")
        filtered.removeValue(forKey: "title")
        return filtered.isEmpty ? nil : .object(filtered)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(String.self, forKey: .type)
        self.title = try container.decodeIfPresent(String.self, forKey: .title)
        let rawPayload = try? JSONValue(from: decoder)
        self.payload = Self.extractPayload(from: rawPayload)
    }

    func encode(to encoder: Encoder) throws {
        if case .object(let payloadObject) = payload {
            var mergedObject = payloadObject
            mergedObject["type"] = .string(type)
            if let title {
                mergedObject["title"] = .string(title)
            }
            try JSONValue.object(mergedObject).encode(to: encoder)
            return
        }

        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(title, forKey: .title)
    }
}

struct ChecklistTask: Identifiable, Hashable, Codable {
    let id: String
    var title: String
    var detail: String?
    var isComplete: Bool
    var isCustom: Bool
    var estimatedMinutes: Int?
    var urgency: TaskUrgency
    var order: Int?
    var timing: TaskTiming
    var priority: TaskPriority
    var content: TaskContent?
    var sourceTitle: String?
    var sourceURL: String?

    init(
        id: String = UUID().uuidString,
        title: String,
        detail: String? = nil,
        isComplete: Bool = false,
        isCustom: Bool = false,
        estimatedMinutes: Int? = nil,
        urgency: TaskUrgency = .medium,
        order: Int? = nil,
        timing: TaskTiming = .anytime,
        priority: TaskPriority = .shouldDo,
        content: TaskContent? = nil,
        sourceTitle: String? = nil,
        sourceURL: String? = nil
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.isComplete = isComplete
        self.isCustom = isCustom
        self.estimatedMinutes = estimatedMinutes
        self.urgency = urgency
        self.order = order
        self.timing = timing
        self.priority = priority
        self.content = content
        self.sourceTitle = sourceTitle
        self.sourceURL = sourceURL
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case detail
        case isComplete
        case isCustom
        case estimatedMinutes
        case urgency
        case order
        case timing
        case priority
        case content
        case sourceTitle
        case sourceURL
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let decodedID = try container.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.id = decodedID.isEmpty ? UUID().uuidString : decodedID
        self.title = try container.decode(String.self, forKey: .title)
        self.detail = try container.decodeIfPresent(String.self, forKey: .detail)
        self.isComplete = try container.decodeIfPresent(Bool.self, forKey: .isComplete) ?? false
        self.isCustom = try container.decodeIfPresent(Bool.self, forKey: .isCustom) ?? false
        self.estimatedMinutes = try container.decodeIfPresent(Int.self, forKey: .estimatedMinutes)
        self.urgency = try container.decodeIfPresent(TaskUrgency.self, forKey: .urgency) ?? .medium
        self.order = try container.decodeIfPresent(Int.self, forKey: .order)
        self.timing = try container.decodeIfPresent(TaskTiming.self, forKey: .timing) ?? .anytime
        self.priority = try container.decodeIfPresent(TaskPriority.self, forKey: .priority) ?? .shouldDo
        self.content = try container.decodeIfPresent(TaskContent.self, forKey: .content)
        self.sourceTitle = try container.decodeIfPresent(String.self, forKey: .sourceTitle)
        self.sourceURL = try container.decodeIfPresent(String.self, forKey: .sourceURL)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(detail, forKey: .detail)
        try container.encode(isComplete, forKey: .isComplete)
        try container.encode(isCustom, forKey: .isCustom)
        try container.encodeIfPresent(estimatedMinutes, forKey: .estimatedMinutes)
        try container.encode(urgency, forKey: .urgency)
        try container.encodeIfPresent(order, forKey: .order)
        try container.encode(timing, forKey: .timing)
        try container.encode(priority, forKey: .priority)
        try container.encodeIfPresent(content, forKey: .content)
        try container.encodeIfPresent(sourceTitle, forKey: .sourceTitle)
        try container.encodeIfPresent(sourceURL, forKey: .sourceURL)
    }
}

struct ChecklistCategory: Identifiable, Hashable, Codable {
    let id: String
    var title: String
    var subtitle: String?
    var categoryType: String?
    var icon: String
    var gradient: [String]?
    var priority: Int?
    var priorityLevel: CategoryPriorityLevel?
    var urgency: CategoryUrgencyBand?
    var accentColorHex: String?
    var deadline: String?
    var isVisibleOverride: Bool?
    var order: Int?
    var cityFilters: [String]?
    var universityFilters: [String]?
    var unlockRequirements: String?
    var tasks: [ChecklistTask]

    var isVisible: Bool {
        isVisibleOverride ?? true
    }

    var visualPriority: CategoryPriorityLevel {
        if let priorityLevel {
            return priorityLevel
        }
        if let priority {
            return CategoryPriorityLevel.fromLegacy(priority: priority)
        }
        switch urgencyBand {
        case .immediate:
            return .critical
        case .week1:
            return .high
        case .week2:
            return .medium
        case .anytime, .completed:
            return .low
        }
    }

    var urgencyBand: CategoryUrgencyBand {
        if !tasks.isEmpty && tasks.allSatisfy(\.isComplete) {
            return .completed
        }
        if let urgency {
            return urgency
        }
        if tasks.contains(where: { $0.timing == .monthBeforeArrival || $0.timing == .weekBeforeArrival }) {
            return .immediate
        }
        if tasks.contains(where: { $0.timing == .firstWeek }) {
            return .week1
        }
        if tasks.contains(where: { $0.timing == .firstMonth }) {
            return .week2
        }
        if tasks.contains(where: { $0.priority == .mustDo }) {
            return .week1
        }
        return .anytime
    }

    var resolvedSubtitle: String {
        if let subtitle, !subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return subtitle
        }
        if let unlockRequirements, !unlockRequirements.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return unlockRequirements
        }
        if tasks.isEmpty {
            return "No tasks available yet"
        }
        switch urgencyBand {
        case .immediate:
            return "Must complete before arrival"
        case .week1:
            return "Important for your first week"
        case .week2:
            return "Plan this in your first month"
        case .anytime:
            return "Complete when convenient"
        case .completed:
            return "All tasks completed"
        }
    }

    var deadlineLabel: String? {
        guard let deadline, !deadline.isEmpty else {
            return nil
        }
        if let date = Self.deadlineInputFormatter.date(from: deadline) ?? Self.fallbackDeadlineFormatter.date(from: deadline) {
            return Self.deadlineOutputFormatter.string(from: date)
        }
        return deadline
    }

    func matchesAudience(city: String, university: String) -> Bool {
        let filters = AudienceFilters(
            cities: cityFilters ?? [],
            universities: universityFilters ?? []
        )
        return filters.matches(city: city, university: university)
    }

    init(
        id: String,
        title: String,
        subtitle: String? = nil,
        categoryType: String? = nil,
        icon: String,
        gradient: [String]? = nil,
        priority: Int? = nil,
        priorityLevel: CategoryPriorityLevel? = nil,
        urgency: CategoryUrgencyBand? = nil,
        accentColorHex: String? = nil,
        deadline: String? = nil,
        isVisibleOverride: Bool? = nil,
        order: Int? = nil,
        cityFilters: [String]? = nil,
        universityFilters: [String]? = nil,
        unlockRequirements: String? = nil,
        tasks: [ChecklistTask]
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.categoryType = categoryType
        self.icon = icon
        self.gradient = gradient
        self.priority = priority
        self.priorityLevel = priorityLevel
        self.urgency = urgency
        self.accentColorHex = accentColorHex
        self.deadline = deadline
        self.isVisibleOverride = isVisibleOverride
        self.order = order
        self.cityFilters = cityFilters
        self.universityFilters = universityFilters
        self.unlockRequirements = unlockRequirements
        self.tasks = tasks
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case subtitle
        case type
        case categoryType
        case icon
        case gradient
        case priority
        case priorityLevel
        case visualPriority
        case urgency
        case accentColor
        case accentColorHex
        case deadline
        case isVisible
        case order
        case cityFilters
        case universityFilters
        case cities
        case universities
        case unlockRequirements
        case tasks
    }

    private static let deadlineInputFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter
    }()

    private static let fallbackDeadlineFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let deadlineOutputFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let decodedID = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        self.id = decodedID.isEmpty ? UUID().uuidString : decodedID
        self.title = try container.decode(String.self, forKey: .title)
        self.subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle)
        self.categoryType =
            (try? container.decodeIfPresent(String.self, forKey: .type)) ??
            (try? container.decodeIfPresent(String.self, forKey: .categoryType))
        self.icon = try container.decodeIfPresent(String.self, forKey: .icon) ?? "square.grid.2x2"
        self.gradient = try container.decodeIfPresent([String].self, forKey: .gradient)

        if let numericPriority = try? container.decode(Int.self, forKey: .priority) {
            self.priority = numericPriority
            self.priorityLevel = nil
        } else if let rawPriority = try? container.decode(String.self, forKey: .priority),
                  let parsedPriority = CategoryPriorityLevel(rawValue: rawPriority.lowercased()) {
            self.priority = nil
            self.priorityLevel = parsedPriority
        } else if let explicitPriority = try? container.decode(CategoryPriorityLevel.self, forKey: .priorityLevel) {
            self.priority = nil
            self.priorityLevel = explicitPriority
        } else if let visualPriority = try? container.decode(CategoryPriorityLevel.self, forKey: .visualPriority) {
            self.priority = nil
            self.priorityLevel = visualPriority
        } else {
            self.priority = nil
            self.priorityLevel = nil
        }

        self.urgency = try container.decodeIfPresent(CategoryUrgencyBand.self, forKey: .urgency)

        if let accentColor = try container.decodeIfPresent(String.self, forKey: .accentColor) {
            self.accentColorHex = accentColor
        } else {
            self.accentColorHex = try container.decodeIfPresent(String.self, forKey: .accentColorHex)
        }

        self.deadline = try container.decodeIfPresent(String.self, forKey: .deadline)
        self.isVisibleOverride = try container.decodeIfPresent(Bool.self, forKey: .isVisible)
        self.order = try container.decodeIfPresent(Int.self, forKey: .order)
        self.cityFilters =
            (try? container.decodeIfPresent([String].self, forKey: .cityFilters)) ??
            (try? container.decodeIfPresent([String].self, forKey: .cities))
        self.universityFilters =
            (try? container.decodeIfPresent([String].self, forKey: .universityFilters)) ??
            (try? container.decodeIfPresent([String].self, forKey: .universities))
        self.unlockRequirements = try container.decodeIfPresent(String.self, forKey: .unlockRequirements)
        self.tasks = try container.decodeIfPresent([ChecklistTask].self, forKey: .tasks) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(subtitle, forKey: .subtitle)
        try container.encodeIfPresent(categoryType, forKey: .type)
        try container.encode(icon, forKey: .icon)
        try container.encodeIfPresent(gradient, forKey: .gradient)
        if let priorityLevel {
            try container.encode(priorityLevel.rawValue, forKey: .priority)
        } else {
            try container.encodeIfPresent(priority, forKey: .priority)
        }
        try container.encodeIfPresent(urgency, forKey: .urgency)
        try container.encodeIfPresent(accentColorHex, forKey: .accentColor)
        try container.encodeIfPresent(deadline, forKey: .deadline)
        try container.encodeIfPresent(isVisibleOverride, forKey: .isVisible)
        try container.encodeIfPresent(order, forKey: .order)
        try container.encodeIfPresent(cityFilters, forKey: .cityFilters)
        try container.encodeIfPresent(universityFilters, forKey: .universityFilters)
        try container.encodeIfPresent(unlockRequirements, forKey: .unlockRequirements)
        try container.encode(tasks, forKey: .tasks)
    }
}

enum SampleData {
    static let categories: [ChecklistCategory] = [
        ChecklistCategory(
            id: "before_arrival",
            title: "Before Arrival",
            subtitle: "Must complete before landing",
            icon: "airplane.departure",
            gradient: ["#667EEA", "#764BA2"],
            priorityLevel: .critical,
            urgency: .immediate,
            tasks: [
                ChecklistTask(
                    id: "before_visa_check",
                    title: "Confirm visa documents are complete",
                    detail: "Double-check passport validity, CAS details, and proof of funds before travel.",
                    timing: .monthBeforeArrival,
                    priority: .mustDo,
                    sourceTitle: "UK Student Visa Guidance (GOV.UK)",
                    sourceURL: "https://www.gov.uk/student-visa"
                ),
                ChecklistTask(
                    id: "before_uni_letter",
                    title: "Download university status letter template",
                    detail: "Prepare a digital copy so bank account and admin steps are faster after arrival.",
                    timing: .weekBeforeArrival,
                    priority: .shouldDo
                ),
                ChecklistTask(
                    id: "before_housing_docs",
                    title: "Prepare housing and ID document pack",
                    detail: "Keep tenancy agreement, passport, visa proof, and offer letter in one folder.",
                    timing: .weekBeforeArrival,
                    priority: .mustDo
                ),
                ChecklistTask(
                    id: "before_budget",
                    title: "Set first-month budget",
                    detail: "Estimate rent, groceries, transport, and emergency spending for your first month.",
                    timing: .weekBeforeArrival,
                    priority: .shouldDo
                )
            ]
        ),
        ChecklistCategory(
            id: "health_admin",
            title: "Health & Admin",
            subtitle: "Important for your first week",
            icon: "heart.text.square",
            gradient: ["#F093FB", "#F5576C"],
            priorityLevel: .high,
            urgency: .week1,
            tasks: [
                ChecklistTask(
                    id: "health_gp",
                    title: "Register with a GP surgery",
                    detail: "Do this soon after settling so healthcare access is ready when needed.",
                    timing: .firstWeek,
                    priority: .mustDo,
                    sourceTitle: "How to Register with a GP (NHS)",
                    sourceURL: "https://www.nhs.uk/nhs-services/gps/how-to-register-with-a-gp-surgery/"
                ),
                ChecklistTask(
                    id: "health_ni",
                    title: "Apply for National Insurance number",
                    detail: "Needed for legal employment and correct tax setup in part-time or full-time work.",
                    timing: .firstMonth,
                    priority: .mustDo,
                    sourceTitle: "Apply for a National Insurance Number (GOV.UK)",
                    sourceURL: "https://www.gov.uk/apply-national-insurance-number"
                ),
                ChecklistTask(
                    id: "health_council_tax",
                    title: "Submit council tax student exemption",
                    detail: "Use your student proof to avoid paying full council tax where eligible.",
                    timing: .firstMonth,
                    priority: .shouldDo,
                    sourceTitle: "Council Tax Discounts for Students (GOV.UK)",
                    sourceURL: "https://www.gov.uk/council-tax/discounts-for-full-time-students"
                )
            ]
        ),
        ChecklistCategory(
            id: "money_banking",
            title: "Money & Banking",
            subtitle: "Money setup and daily essentials",
            icon: "banknote",
            gradient: ["#FCCF31", "#F55555"],
            priorityLevel: .medium,
            urgency: .week1,
            tasks: [
                ChecklistTask(
                    id: "money_open_account",
                    title: "Open a UK bank account",
                    detail: "Compare student accounts and keep your enrollment letter ready for verification.",
                    timing: .firstWeek,
                    priority: .mustDo
                ),
                ChecklistTask(
                    id: "money_alerts",
                    title: "Enable spending alerts and limits",
                    detail: "Turn on transaction notifications to avoid overspending during early setup weeks.",
                    timing: .firstWeek,
                    priority: .shouldDo
                ),
                ChecklistTask(
                    id: "money_emergency_buffer",
                    title: "Create a small emergency buffer",
                    detail: "Aim for a minimum reserve so unexpected transport or medical costs are covered.",
                    timing: .firstMonth,
                    priority: .optional
                )
            ]
        ),
        ChecklistCategory(
            id: "travel_discounts",
            title: "Travel & Discounts",
            subtitle: "Important for your first week",
            icon: "tram",
            gradient: ["#4FACFE", "#00F2FE"],
            priorityLevel: .low,
            urgency: .anytime,
            tasks: [
                ChecklistTask(
                    id: "travel_railcard",
                    title: "Buy a 16-25 Railcard (if eligible)",
                    detail: "Can reduce train fares significantly during term and holiday travel.",
                    timing: .firstMonth,
                    priority: .shouldDo,
                    sourceTitle: "16-25 Railcard",
                    sourceURL: "https://www.16-25railcard.co.uk/"
                ),
                ChecklistTask(
                    id: "travel_local_pass",
                    title: "Check local student transport pass",
                    detail: "Many cities offer discounted bus or metro options for students.",
                    timing: .firstMonth,
                    priority: .shouldDo
                ),
                ChecklistTask(
                    id: "travel_route_setup",
                    title: "Save key routes in transport apps",
                    detail: "Pre-save campus, accommodation, supermarket, and nearest hospital routes.",
                    timing: .firstWeek,
                    priority: .optional
                )
            ]
        )
    ]
}


```

## arrival uk/Networking/SecureHTTPClient.swift

```swift
import Foundation

/// Minimal, production-safe networking client that enforces HTTPS by default.
/// Requires iOS 17.0+
@available(iOS 17.0, *)
final class SecureHTTPClient {
    static let shared = SecureHTTPClient()

    private let session: URLSession

    init(configuration: URLSessionConfiguration = .default) {
        let config = configuration
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
    }

    func request<Response: Decodable>(
        endpoint: String,
        method: HTTPMethod = .get,
        headers: [String: String] = [:],
        body: Data? = nil,
        decoder: JSONDecoder = JSONDecoder()
    ) async throws -> Response {
        guard let url = URL(string: endpoint) else {
            throw SecureHTTPClientError.invalidURL(endpoint)
        }

        guard let scheme = url.scheme?.lowercased(), scheme == "https" else {
            throw SecureHTTPClientError.insecureScheme(url.absoluteString)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("arrival-uk-ios/1.0", forHTTPHeaderField: "User-Agent")

        for (header, value) in headers {
            request.setValue(value, forHTTPHeaderField: header)
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw SecureHTTPClientError.transport(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SecureHTTPClientError.invalidResponse
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw SecureHTTPClientError.httpStatus(httpResponse.statusCode)
        }

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw SecureHTTPClientError.decoding(error)
        }
    }
}

@available(iOS 17.0, *)
enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

@available(iOS 17.0, *)
enum SecureHTTPClientError: LocalizedError {
    case invalidURL(String)
    case insecureScheme(String)
    case invalidResponse
    case httpStatus(Int)
    case transport(Error)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let endpoint):
            return "Invalid URL: \(endpoint)"
        case .insecureScheme(let endpoint):
            return "Insecure URL scheme is not allowed: \(endpoint)"
        case .invalidResponse:
            return "Server returned an invalid response."
        case .httpStatus(let statusCode):
            return "Server request failed with status \(statusCode)."
        case .transport(let error):
            return "Network transport error: \(error.localizedDescription)"
        case .decoding(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        }
    }
}

```

## arrival uk/Security/ExternalURLPolicy.swift

```swift
import Foundation

enum ExternalURLPolicy {
    // Strict allow-list for plain HTTP. HTTPS is allowed globally.
    private static let trustedHTTPDomainSuffixes: [String] = [
        "gov.uk",
        "ac.uk",
        "nhs.uk",
        "ukcisa.org.uk",
        "nationalrail.co.uk",
        "maps.apple.com"
    ]

    // Stronger trust list used for content marked as official/university.
    static let trustedOfficialDomainSuffixes: [String] = [
        "gov.uk",
        "ac.uk",
        "nhs.uk",
        "ukri.org.uk",
        "ukfinance.org.uk",
        "ukcisa.org.uk",
        "nationalrail.co.uk"
    ]

    static func normalizedURL(from rawValue: String) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed) else {
            return nil
        }
        return isAllowed(url) ? url : nil
    }

    static func isAllowed(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }

        switch scheme {
        case "https":
            return isValidHost(url.host)
        case "http":
            guard let host = url.host?.lowercased(), isValidHost(host) else { return false }
            return trustedHTTPDomainSuffixes.contains { host == $0 || host.hasSuffix(".\($0)") }
        default:
            return false
        }
    }

    static func isTrustedOfficialOrUniversityHost(_ host: String) -> Bool {
        let lowered = host.lowercased()
        return trustedOfficialDomainSuffixes.contains { lowered == $0 || lowered.hasSuffix(".\($0)") }
    }

    private static func isValidHost(_ host: String?) -> Bool {
        guard let host = host?.trimmingCharacters(in: .whitespacesAndNewlines), !host.isEmpty else {
            return false
        }

        let lowered = host.lowercased()

        // Block localhost and obvious local-network targets for external navigation.
        if lowered == "localhost" || lowered.hasSuffix(".local") {
            return false
        }

        if lowered == "127.0.0.1" || lowered == "0.0.0.0" {
            return false
        }

        return true
    }
}

```

## arrival uk/Security/KeychainManager.swift

```swift
import Foundation
import Security

enum KeychainManager {
    enum KeychainError: Error {
        case duplicateItem
        case itemNotFound
        case invalidData
        case unhandledError(status: OSStatus)
    }

    @discardableResult
    static func save(data: Data, for key: String) -> Bool {
        (try? saveThrowing(data: data, for: key)) != nil
    }

    static func saveThrowing(
        data: Data,
        for key: String,
        accessibility: CFString = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    ) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: accessibility
        ]

        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unhandledError(status: status)
        }
    }

    static func load(for key: String) -> Data? {
        try? loadThrowing(for: key)
    }

    static func loadThrowing(for key: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.unhandledError(status: status)
        }
        guard let data = result as? Data else {
            throw KeychainError.invalidData
        }
        return data
    }

    @discardableResult
    static func delete(for key: String) -> Bool {
        (try? deleteThrowing(for: key)) != nil
    }

    static func deleteThrowing(for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledError(status: status)
        }
    }

    @discardableResult
    static func saveString(_ value: String, for key: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        return (try? saveThrowing(data: data, for: key)) != nil
    }

    static func loadString(for key: String) -> String? {
        guard let data = try? loadThrowing(for: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func saveStringThrowing(_ value: String, for key: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        try saveThrowing(data: data, for: key)
    }

    static func loadStringThrowing(for key: String) throws -> String {
        let data = try loadThrowing(for: key)
        guard let value = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }
        return value
    }
}

```

## arrival uk/StudentProfile.swift

```swift
import Foundation
import Observation
import AuthenticationServices

enum StudentAuthProvider: String, Codable, Hashable {
    case none
    case apple
    case google

    var label: String {
        switch self {
        case .none:
            return "Not signed in"
        case .apple:
            return "Apple"
        case .google:
            return "Google"
        }
    }
}

enum StudyLevel: String, CaseIterable, Codable, Hashable {
    case foundation
    case undergraduate
    case postgraduate
    case phd
    case other

    var label: String {
        switch self {
        case .foundation:
            return "Foundation"
        case .undergraduate:
            return "Undergraduate"
        case .postgraduate:
            return "Postgraduate"
        case .phd:
            return "PhD"
        case .other:
            return "Other"
        }
    }
}

struct StudentProfileSnapshot: Codable, Equatable {
    var authProvider: StudentAuthProvider
    var appleUserID: String?
    var googleUserID: String?
    var fullName: String
    var email: String
    var selectedUniversity: String
    var courseName: String
    var city: String
    var studyLevel: StudyLevel
    var arrivalDate: Date
    var hasCompletedSetup: Bool
}

@Observable
final class StudentProfileStore {
    static let shared = StudentProfileStore()

    private let defaults = UserDefaults.standard
    private let storageKey = "student.profile.v1"
    private let keychainAuthTokenKey = "student.auth.token"
    private let keychainRefreshTokenKey = "student.auth.refresh"
    private var hasBootstrapped = false

    var authProvider: StudentAuthProvider = .none
    var appleUserID: String?
    var googleUserID: String?
    var fullName: String = ""
    var email: String = ""
    var selectedUniversity: String = ""
    var courseName: String = ""
    var city: String = ""
    var studyLevel: StudyLevel = .undergraduate
    var arrivalDate: Date = .now
    var hasCompletedSetup: Bool = false

    var preferredFirstName: String? {
        let trimmed = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed.split(separator: " ").first.map(String.init)
    }

    private init() {}

    @MainActor
    func bootstrapIfNeeded() {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true
        loadFromDefaults()
    }

    @MainActor
    func setGoogleMode() {
        authProvider = .google
        appleUserID = nil
        googleUserID = nil
        persist()
    }

    @MainActor
    func setGoogleIdentity(email: String, userID: String? = nil) {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedEmail.isEmpty else { return }
        authProvider = .google
        appleUserID = nil
        googleUserID = userID
        self.email = normalizedEmail.lowercased()
        persist()
    }

    @MainActor
    func applyGoogleIdentity(_ identity: GoogleSignInIdentity) {
        authProvider = .google
        appleUserID = nil
        googleUserID = identity.userID
        email = identity.email.lowercased()
        if fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let name = identity.fullName,
           !name.isEmpty {
            fullName = name
        }
        persist()
    }

    @MainActor
    func clearAuthentication() {
        authProvider = .none
        appleUserID = nil
        googleUserID = nil
        email = ""
        persist()
    }

    /// Clears all local authentication state including any future Keychain-backed session secrets.
    @MainActor
    func secureSignOut() {
        secureSignOut(contentStore: .shared)
    }

    @MainActor
    func secureSignOut(contentStore: ContentStore) {
        logout(contentStore: contentStore)
    }

    /// Full local logout: clears auth, profile fields, and optional checklist progress.
    @MainActor
    func logout() {
        logout(contentStore: .shared)
    }

    @MainActor
    func logout(contentStore: ContentStore) {
        authProvider = .none
        appleUserID = nil
        googleUserID = nil
        fullName = ""
        email = ""
        selectedUniversity = ""
        courseName = ""
        city = ""
        studyLevel = .undergraduate
        arrivalDate = .now
        hasCompletedSetup = false

        defaults.removeObject(forKey: storageKey)
        _ = KeychainManager.delete(for: keychainAuthTokenKey)
        _ = KeychainManager.delete(for: keychainRefreshTokenKey)
        contentStore.clearAllProgress()
        syncCrashReporterIdentity()
    }

    @MainActor
    func applyAppleCredential(_ credential: ASAuthorizationAppleIDCredential) {
        authProvider = .apple
        appleUserID = credential.user
        googleUserID = nil

        if let email = credential.email, !email.isEmpty {
            self.email = email.lowercased()
        }

        if let givenName = credential.fullName?.givenName, !givenName.isEmpty {
            let familyName = credential.fullName?.familyName ?? ""
            let combined = "\(givenName) \(familyName)".trimmingCharacters(in: .whitespacesAndNewlines)
            if !combined.isEmpty {
                fullName = combined
            }
        }

        persist()
    }

    @MainActor
    func updateProfile(
        fullName: String,
        selectedUniversity: String,
        courseName: String,
        city: String,
        studyLevel: StudyLevel,
        arrivalDate: Date
    ) {
        self.fullName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.selectedUniversity = selectedUniversity.trimmingCharacters(in: .whitespacesAndNewlines)
        self.courseName = courseName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.city = city.trimmingCharacters(in: .whitespacesAndNewlines)
        self.studyLevel = studyLevel
        self.arrivalDate = arrivalDate
        hasCompletedSetup = !self.fullName.isEmpty && !self.selectedUniversity.isEmpty
        persist()
    }

    @MainActor
    private func loadFromDefaults() {
        guard
            let data = defaults.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode(StudentProfileSnapshot.self, from: data)
        else {
            return
        }

        let snapshot = AuthStateValidator.normalize(decoded)

        authProvider = snapshot.authProvider
        appleUserID = snapshot.appleUserID
        googleUserID = snapshot.googleUserID
        fullName = snapshot.fullName
        email = snapshot.email
        selectedUniversity = snapshot.selectedUniversity
        courseName = snapshot.courseName
        city = snapshot.city
        studyLevel = snapshot.studyLevel
        arrivalDate = snapshot.arrivalDate
        hasCompletedSetup = snapshot.hasCompletedSetup

        // If the snapshot required normalization, immediately persist the corrected state.
        if snapshot != decoded {
            persist()
        } else {
            syncCrashReporterIdentity()
        }
    }

    @MainActor
    private func persist() {
        let snapshot = StudentProfileSnapshot(
            authProvider: authProvider,
            appleUserID: appleUserID,
            googleUserID: googleUserID,
            fullName: fullName,
            email: email,
            selectedUniversity: selectedUniversity,
            courseName: courseName,
            city: city,
            studyLevel: studyLevel,
            arrivalDate: arrivalDate,
            hasCompletedSetup: hasCompletedSetup
        )

        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: storageKey)
        syncCrashReporterIdentity()
    }

    @MainActor
    private func syncCrashReporterIdentity() {
        let identifier: String?

        switch authProvider {
        case .apple:
            identifier = appleUserID
        case .google:
            identifier = googleUserID
        case .none:
            identifier = nil
        }

        CrashReporter.setUserIdentifier(identifier)
    }
}

enum UniversityCatalog {
    static let popularUK: [String] = [
        "University of Oxford",
        "University of Cambridge",
        "Imperial College London",
        "UCL",
        "King's College London",
        "University of Edinburgh",
        "University of Manchester",
        "University of Birmingham",
        "University of Leeds",
        "University of Glasgow",
        "University of Bristol",
        "University of Nottingham",
        "University of Sheffield",
        "University of Warwick",
        "Queen Mary University of London",
        "University of Southampton",
        "Newcastle University",
        "University of Liverpool",
        "University of York",
        "University of Exeter"
    ]
}

```

## arrival uk/arrival_ukApp.swift

```swift
//
//  arrival_ukApp.swift
//  arrival uk
//
//  Created by Abdul Hannan on 2/3/26.
//

import SwiftUI

@main
struct arrival_ukApp: App {
    init() {
        CrashReporter.bootstrapIfNeeded()
        if #available(iOS 17.0, *) {
            PushNotificationManager.shared.configureIfNeeded()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

```

## backend-docs/api-specification-v1.md

```md
# API Specification v1 (Contract Draft)

Last updated: 2026-02-10
Base URL: `https://api.yourapp.com/v1`
Auth: `Authorization: Bearer <firebase-id-token>`

## User
- `POST /auth/register`
- `GET /users/me`
- `PUT /users/me`
- `DELETE /users/me`

## Content
- `GET /content/categories`
- `GET /content/categories/{categoryId}`
- `GET /content/tasks/{taskId}`
- `GET /content/search?q=...&limit=...`

## Progress
- `GET /progress`
- `POST /progress/tasks/{taskId}/complete`
- `DELETE /progress/tasks/{taskId}/complete`

## Custom Tasks
- `GET /users/me/tasks`
- `POST /users/me/tasks`
- `PUT /users/me/tasks/{taskId}`
- `DELETE /users/me/tasks/{taskId}`

## Notifications
- `GET /notifications/settings`
- `PUT /notifications/settings`
- `POST /notifications/register-device`

## Analytics
- `POST /analytics/events`
- `GET /analytics/insights`

## Support
- `POST /support/tickets`
- `GET /support/tickets`
- `POST /support/tickets/{ticketId}/messages`

## Referrals
- `GET /referrals/me`
- `POST /referrals/claim`

## Premium
- `GET /premium/status`
- `POST /premium/purchase`

## Monetization Tracking
- `POST /monetization/ad-impression`
- `POST /monetization/affiliate-click`

## Partnerships
- `GET /partnerships/featured?category=...&limit=...`

## Error Envelope
```json
{
  "error": {
    "code": "invalid_request",
    "message": "Missing required field"
  }
}
```

## Status Codes
- `400` invalid request
- `401` unauthenticated/expired token
- `403` forbidden
- `404` not found
- `429` rate limited
- `500` internal error

```

## backend-docs/chunk-1-gap-analysis.md

```md
# Chunk 1 Gap Analysis (Applied Against Current Codebase)

Last updated: 2026-02-10

## Already Implemented (no duplicate changes made)
- Keychain storage utility:
  - `/Users/abdulhannan/Desktop/arrival uk/arrival uk/Security/KeychainManager.swift`
- Secure logout path + progress clear:
  - `/Users/abdulhannan/Desktop/arrival uk/arrival uk/StudentProfile.swift`
- URL allow-list policy:
  - `/Users/abdulhannan/Desktop/arrival uk/arrival uk/Security/ExternalURLPolicy.swift`
- HTTPS-enforced HTTP client:
  - `/Users/abdulhannan/Desktop/arrival uk/arrival uk/Networking/SecureHTTPClient.swift`
- Auth state validation:
  - `/Users/abdulhannan/Desktop/arrival uk/arrival uk/Auth/AuthStateValidator.swift`
- Task search and reminders:
  - `/Users/abdulhannan/Desktop/arrival uk/arrival uk/Features/Search/TaskSearchSheet.swift`
  - `/Users/abdulhannan/Desktop/arrival uk/arrival uk/Features/Notifications/NotificationManager.swift`
- Crash reporting bootstrap:
  - `/Users/abdulhannan/Desktop/arrival uk/arrival uk/Core/CrashReporter.swift`

## Added in this chunk (net-new)
- Backend architecture document:
  - `/Users/abdulhannan/Desktop/arrival uk/backend-docs/firebase-architecture.md`
- Firestore data model and index plan:
  - `/Users/abdulhannan/Desktop/arrival uk/backend-docs/firestore-data-model.md`
- REST API v1 contract draft:
  - `/Users/abdulhannan/Desktop/arrival uk/backend-docs/api-specification-v1.md`
- Cloud Functions scaffold for auth lifecycle:
  - `/Users/abdulhannan/Desktop/arrival uk/backend/functions/auth.ts`
  - `/Users/abdulhannan/Desktop/arrival uk/backend/functions/package.json`
  - `/Users/abdulhannan/Desktop/arrival uk/backend/functions/tsconfig.json`

## Deferred to later chunks
- Wiring FirebaseAuth/Firestore/Functions runtime into iOS target.
- Firestore rules/index deployment automation.
- CI/CD workflows and environment provisioning.

```

## backend-docs/chunk-2-gap-analysis.md

```md
# Chunk 2 Gap Analysis (Infra/Storage/Email/Push)

Last updated: 2026-02-10

## Applied in this chunk (net-new)

- Infra setup guide:
  - `backend-docs/firebase-setup-complete.md`
- Storage/CDN architecture guide:
  - `backend-docs/storage-architecture.md`
- Backend function scaffolds:
  - `backend/functions/src/notifications.ts`
  - `backend/functions/src/email.ts`
  - `backend/functions/src/sms.ts`
  - `backend/functions/src/storage.ts`
- Functions export wiring:
  - `backend/functions/src/index.ts`
- Storage rules + firebase config wiring:
  - `backend/storage.rules`
  - `backend/firebase.json`
- iOS push notification scaffold (compile-guarded):
  - `arrival uk/Features/Notifications/PushNotificationManager.swift`
  - `arrival uk/arrival_ukApp.swift`

## Intentionally deferred (to avoid breaking runtime without credentials)

- Live SendGrid/Twilio key provisioning and end-to-end send verification.
- APNs key/cert + entitlements setup for production push.
- Image resizing binaries (`sharp`) pipeline activation.
- Full AppDelegate deep-link + navigation routing hooks for push taps.

## Consistency notes

- Reused existing `canImport(...)` guard pattern for optional Firebase modules.
- Kept backend additions scaffolded and additive; no destructive rewrites of current iOS app logic.


```

## backend-docs/firebase-architecture.md

```md
# Arrival UK Backend Architecture (Phase-Aligned)

Last updated: 2026-02-10

## Objective
Provide a production-safe backend path that keeps current iOS velocity while enabling scale.

## Current App State (already implemented)
- Local-first SwiftUI app with robust content/task model.
- Security primitives present:
  - `KeychainManager` for sensitive secrets.
  - `SecureHTTPClient` enforcing HTTPS.
  - auth-state normalization/validation.
- Crash reporting bootstrap present with Firebase Core + Crashlytics hooks.

## Recommended rollout

### Phase 1 (Launch: 0-3 months)
Use Firebase managed services for speed:
- Firebase Authentication
- Cloud Firestore
- Cloud Storage
- Cloud Functions
- Firebase Analytics + Crashlytics
- FCM notifications

### Phase 2 (Growth: 4-12 months)
Hybrid model:
- Keep Firebase for auth/realtime/events.
- Add custom API service for advanced business logic and integrations.
- Add relational analytics/reporting store for BI.

### Phase 3 (Scale: 12+ months)
Service decomposition:
- User/Profile service
- Content service + CMS pipeline
- Monetization service
- Event pipeline and warehousing

## Firebase Project Baseline
1. Create project and environments: `dev`, `staging`, `prod`.
2. Register iOS app and install `GoogleService-Info.plist` per environment.
3. Enable Auth providers:
   - Apple
   - Google
4. Enable Firestore and deploy rules/indexes.
5. Enable Cloud Functions and deploy auth triggers.
6. Enable Crashlytics/Analytics/FCM.

## Security Model
- Authenticated user can access only their own `/users/{uid}` and nested data.
- Public content read-only for client.
- Writes to `/content/**` restricted to admin service accounts.
- Analytics collection write-only for clients.

## Environment & Secrets
- Keep API keys and server credentials in Firebase/CI secrets, not iOS bundle.
- Any privileged API key usage must be server-side only.

## Operational Practices
- Deploy from CI with tagged releases.
- Keep independent Firestore projects for dev/staging/prod.
- Maintain runbooks for:
  - auth outage
  - notification outage
  - rollback

```

## backend-docs/firebase-setup-complete.md

```md
# Firebase Setup (Complete, Production-Oriented)

Last updated: 2026-02-10

This extends the existing chunk-1 backend scaffold with environment strategy, hardened rules/indexes, functions config, monitoring, and backup controls.

## 1) Environment Model

Use three Firebase projects:

- `arrival-uk-dev`
- `arrival-uk-staging`
- `arrival-uk-prod`

CLI profile pattern:

```bash
firebase use --add
firebase use dev
firebase use staging
firebase use prod
```

Deploy safely:

```bash
# staging only
firebase deploy --project arrival-uk-staging

# production only
firebase deploy --project arrival-uk-prod
```

## 2) Required Firebase Services

- Authentication
- Firestore
- Cloud Functions
- Cloud Storage
- Firebase Hosting (optional admin web)
- Cloud Messaging (FCM)
- Analytics + Crashlytics
- App Distribution (for internal/beta)

## 3) Firestore Rules + Indexes

Source of truth in repo:

- `backend/firestore.rules`
- `backend/firestore.indexes.json`

Deploy:

```bash
cd backend
firebase deploy --only firestore:rules
firebase deploy --only firestore:indexes
```

## 4) Functions Runtime Configuration

Set secrets/config:

```bash
cd backend

firebase functions:config:set app.name="Arrival UK"
firebase functions:config:set app.url="https://arrivaluk.app"
firebase functions:config:set app.support_email="support@arrivaluk.app"

firebase functions:config:set sendgrid.api_key="SG_XXX"
firebase functions:config:set sendgrid.from_email="noreply@arrivaluk.app"

firebase functions:config:set twilio.account_sid="AC_XXX"
firebase functions:config:set twilio.auth_token="XXX"
firebase functions:config:set twilio.phone_number="+44XXXXXXXXXX"
```

View config:

```bash
firebase functions:config:get
```

## 5) Functions Build + Deploy

```bash
cd backend/functions
npm install
npm run build

cd ..
firebase deploy --only functions
```

## 6) Storage Rules

Source of truth in repo:

- `backend/storage.rules`

Deploy:

```bash
cd backend
firebase deploy --only storage
```

## 7) Monitoring and Alerts (Minimum)

Create Cloud Monitoring alerts for:

- Function error rate > 1%
- Function p95 latency > 10s
- Firestore read/write usage > 80%
- Storage usage > 80%
- DAU drop > 20% day-over-day

Operational channel:

- Slack/email for high-severity alerts
- Daily digest for medium severity

## 8) Backup and Recovery

Recommended retention:

- Daily backups: 7 days
- Weekly backups: 4 weeks
- Monthly backups: 12 months

Disaster recovery checklist:

- Restore Firestore export to staging first
- Validate schema + counts
- Roll forward only after verification

## 9) Cost Controls

Set billing budgets and automated alerts:

- 50%
- 75%
- 90%
- 100%

Optimization baseline:

- Cache read-heavy content in function memory/edge cache
- Minimize fan-out writes
- Use composite indexes only where query patterns require them


```

## backend-docs/firestore-data-model.md

```md
# Firestore Data Model (v1)

Last updated: 2026-02-10

## Collections Overview
- `/users/{userId}`
- `/users/{userId}/customTasks/{taskId}`
- `/users/{userId}/progress/{taskId}`
- `/content/categories/{categoryId}`
- `/content/tasks/{taskId}`
- `/analytics/events/{eventId}`
- `/monetization/adImpressions/{impressionId}`
- `/monetization/affiliateClicks/{clickId}`
- `/support/tickets/{ticketId}` and `/support/tickets/{ticketId}/messages/{messageId}`
- `/referrals/{referralCode}`
- `/notifications/queue/{notificationId}`
- `/config/featureFlags`
- `/analytics/daily/{yyyy-mm-dd}`

## User Document Shape
```json
{
  "userId": "uid",
  "email": "student@example.com",
  "displayName": "Student Name",
  "authProvider": "google",
  "profile": {
    "university": "University of Oxford",
    "course": "Computer Science",
    "studyLevel": "undergraduate",
    "city": "Oxford",
    "arrivalDate": "2026-09-15T00:00:00Z",
    "nationality": "IN"
  },
  "preferences": {
    "language": "en",
    "notifications": {
      "taskReminders": true,
      "weeklyDigest": true,
      "productUpdates": false
    },
    "privacy": {
      "allowAnalytics": true,
      "allowPersonalizedAds": true,
      "dataSharing": false
    }
  },
  "progress": {
    "completedTasks": ["task-1"],
    "totalTasks": 50,
    "completionRate": 0.02,
    "lastActivityDate": "timestamp"
  },
  "engagement": {
    "loginCount": 4,
    "referralCode": "ABCD12"
  },
  "monetization": {
    "isPremium": false,
    "premiumExpiryDate": null,
    "lifetimeValue": 0
  },
  "metadata": {
    "createdAt": "timestamp",
    "updatedAt": "timestamp",
    "version": 1,
    "platform": "ios",
    "appVersion": "1.0.0"
  }
}
```

## Content Documents
- `categories` stores card-level metadata (title/icon/order/visibility).
- `tasks` stores canonical task payload and rendering content sections.
- Use `isPublished` + `version` for staged rollouts.
- Optional filters per task:
  - `universityFilters`
  - `countryFilters`
  - `studyLevelFilters`

## Index Strategy
Create indexes for:
1. users by `metadata.createdAt desc`
2. users by `profile.university asc`
3. tasks by `categoryId asc, order asc, isPublished asc`
4. events by `userId asc, eventType asc, timestamp desc`

## Rules Baseline
- User can read/write only their own profile and nested user data.
- Public read on `/content/**`.
- Admin-only writes on `/content/**`.
- `/analytics/**` write-only from authenticated users.

## Versioning
- Keep `metadata.version` on user docs.
- Keep `version` on content docs.
- Add migration handlers in Cloud Functions for schema bumps.

```

## backend-docs/storage-architecture.md

```md
# Storage & CDN Architecture

Last updated: 2026-02-10

## 1) Bucket Layout

Use stable, predictable paths:

```text
gs://<bucket>/
  users/
    {userId}/
      profile/
      documents/
      uploads/
  content/
    categories/
    tasks/
    partners/
  public/
    app-icons/
    illustrations/
    guides/
  backups/
    firestore/
```

## 2) Security Model

Principles:

- Public read only for curated `content/` and `public/`.
- User-owned write/read for `users/{userId}/...`.
- Validate content type and max size in Storage rules.

Rules file:

- `backend/storage.rules`

## 3) Processing Pipeline

Cloud Functions hooks:

- On upload in `users/{userId}/profile/*`
  - normalize metadata
  - optional resize/thumb pipeline
- On user delete
  - remove `users/{userId}/` files

Code scaffold:

- `backend/functions/src/storage.ts`

## 4) CDN & Caching

For public assets:

- aggressive immutable cache for versioned files
- short cache for dynamic manifests

Recommended headers:

- Images/static assets: `public, max-age=31536000, immutable`
- Dynamic JSON: `public, max-age=300`

## 5) iOS Client Guidance

Use async upload/download wrappers with:

- auth check before upload
- strict file-size and MIME validation
- metadata tags (`uploadedBy`, `uploadedAt`, `documentType`)

Implementation target:

- `arrival uk/Features/Storage/StorageManager.swift` (when enabled)


```

## backend/README.md

```md
# Backend Scaffold

This directory contains Firebase-oriented backend scaffolding for architecture rollout.

## Structure
- `/Users/abdulhannan/Desktop/arrival uk/backend/functions`: Cloud Functions source (TypeScript)
- `/Users/abdulhannan/Desktop/arrival uk/backend/firestore.rules`: Firestore security rules
- `/Users/abdulhannan/Desktop/arrival uk/backend/firestore.indexes.json`: Firestore indexes
- `/Users/abdulhannan/Desktop/arrival uk/backend/storage.rules`: Cloud Storage security rules
- `/Users/abdulhannan/Desktop/arrival uk/backend/firebase.json`: Firebase deployment config

## Quick Start
1. `cd /Users/abdulhannan/Desktop/arrival uk/backend/functions`
2. `npm install`
3. `npm run build`
4. from `/Users/abdulhannan/Desktop/arrival uk/backend`: `firebase emulators:start`

## Notes
- This scaffold is intentionally non-invasive to current iOS runtime.
- iOS integration should be enabled in a separate pass after Firebase Auth/Firestore packages are added to Xcode target.
- Email/SMS functions are scaffolded with graceful fallback if provider secrets/dependencies are not yet configured.

```

## backend/firebase.json

```json
{
  "functions": [
    {
      "source": "functions"
    }
  ],
  "firestore": {
    "rules": "firestore.rules",
    "indexes": "firestore.indexes.json"
  },
  "storage": {
    "rules": "storage.rules"
  }
}

```

## backend/firestore.indexes.json

```json
{
  "indexes": [
    {
      "collectionGroup": "users",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "profile.university", "order": "ASCENDING" },
        { "fieldPath": "metadata.createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "users",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "profile.arrivalDate", "order": "ASCENDING" },
        { "fieldPath": "progress.completionRate", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "users",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "preferences.notifications.taskReminders", "order": "ASCENDING" },
        { "fieldPath": "profile.arrivalDate", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "pending",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "sent", "order": "ASCENDING" },
        { "fieldPath": "scheduledFor", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "items",
      "queryScope": "COLLECTION_GROUP",
      "fields": [
        { "fieldPath": "categoryId", "order": "ASCENDING" },
        { "fieldPath": "order", "order": "ASCENDING" },
        { "fieldPath": "isPublished", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "items",
      "queryScope": "COLLECTION_GROUP",
      "fields": [
        { "fieldPath": "userId", "order": "ASCENDING" },
        { "fieldPath": "eventType", "order": "ASCENDING" },
        { "fieldPath": "timestamp", "order": "DESCENDING" }
      ]
    }
  ],
  "fieldOverrides": []
}

```

## backend/firestore.rules

```text
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function isSignedIn() {
      return request.auth != null;
    }

    function isOwner(userId) {
      return isSignedIn() && request.auth.uid == userId;
    }

    function isAdmin() {
      return isSignedIn()
        && exists(/databases/$(database)/documents/admins/$(request.auth.uid));
    }

    function ticketPath(ticketId) {
      return /databases/$(database)/documents/support/tickets/items/$(ticketId);
    }

    function ticketExists(ticketId) {
      return exists(ticketPath(ticketId));
    }

    function isTicketOwner(ticketId) {
      return isSignedIn()
        && ticketExists(ticketId)
        && get(ticketPath(ticketId)).data.userId == request.auth.uid;
    }

    // User root profile
    match /users/{userId} {
      allow read: if isOwner(userId) || isAdmin();
      allow create: if isOwner(userId);
      allow update, delete: if isOwner(userId) || isAdmin();
    }

    // User-owned nested data
    match /users/{userId}/{document=**} {
      allow read, write: if isOwner(userId) || isAdmin();
    }

    // Public content (authoring by admins only)
    match /content/{document=**} {
      allow read: if true;
      allow write: if isAdmin();
    }

    // Analytics: users can write events, read reserved for admin tools
    match /analytics/events/items/{eventId} {
      allow create: if isSignedIn()
                    && request.resource.data.userId == request.auth.uid;
      allow read: if isAdmin();
      allow update, delete: if false;
    }

    match /analytics/{document=**} {
      allow read, write: if isAdmin();
    }

    // Support
    match /support/tickets/items/{ticketId} {
      allow create: if isSignedIn()
                    && request.resource.data.userId == request.auth.uid;
      allow read: if isSignedIn()
                  && (resource.data.userId == request.auth.uid || isAdmin());
      allow update, delete: if isAdmin();
    }

    match /support/tickets/items/{ticketId}/messages/{messageId} {
      allow create: if isTicketOwner(ticketId)
                    && request.resource.data.userId == request.auth.uid;
      allow read: if isTicketOwner(ticketId) || isAdmin();
      allow update, delete: if isAdmin();
    }

    // Referral and partnerships/public config
    match /referrals/{referralCode} {
      allow read: if true;
      allow create: if isSignedIn()
                    && request.resource.data.ownerUserId == request.auth.uid;
      allow update: if isSignedIn()
                    && resource.data.ownerUserId == request.auth.uid
                    && request.resource.data.ownerUserId == resource.data.ownerUserId;
      allow delete: if isAdmin();
    }

    match /partnerships/{document=**} {
      allow read: if true;
      allow write: if isAdmin();
    }

    match /config/{document=**} {
      allow read: if true;
      allow write: if isAdmin();
    }

    // Notification queue is backend-managed
    match /notifications/{document=**} {
      allow read: if isAdmin();
      allow write: if false;
    }

    // Default deny
    match /{document=**} {
      allow read, write: if false;
    }
  }
}

```

## backend/functions/package-lock.json

```json
{
  "name": "arrival-uk-functions",
  "lockfileVersion": 3,
  "requires": true,
  "packages": {
    "": {
      "name": "arrival-uk-functions",
      "dependencies": {
        "@sendgrid/mail": "^8.1.5",
        "firebase-admin": "^12.6.0",
        "firebase-functions": "^5.1.1",
        "twilio": "^5.5.3"
      },
      "devDependencies": {
        "typescript": "^5.6.3"
      },
      "engines": {
        "node": "20"
      }
    },
    "node_modules/@fastify/busboy": {
      "version": "3.2.0",
      "resolved": "https://registry.npmjs.org/@fastify/busboy/-/busboy-3.2.0.tgz",
      "integrity": "sha512-m9FVDXU3GT2ITSe0UaMA5rU3QkfC/UXtCU8y0gSN/GugTqtVldOBWIB5V6V3sbmenVZUIpU6f+mPEO2+m5iTaA==",
      "license": "MIT"
    },
    "node_modules/@firebase/app-check-interop-types": {
      "version": "0.3.2",
      "resolved": "https://registry.npmjs.org/@firebase/app-check-interop-types/-/app-check-interop-types-0.3.2.tgz",
      "integrity": "sha512-LMs47Vinv2HBMZi49C09dJxp0QT5LwDzFaVGf/+ITHe3BlIhUiLNttkATSXplc89A2lAaeTqjgqVkiRfUGyQiQ==",
      "license": "Apache-2.0"
    },
    "node_modules/@firebase/app-types": {
      "version": "0.9.2",
      "resolved": "https://registry.npmjs.org/@firebase/app-types/-/app-types-0.9.2.tgz",
      "integrity": "sha512-oMEZ1TDlBz479lmABwWsWjzHwheQKiAgnuKxE0pz0IXCVx7/rtlkx1fQ6GfgK24WCrxDKMplZrT50Kh04iMbXQ==",
      "license": "Apache-2.0"
    },
    "node_modules/@firebase/auth-interop-types": {
      "version": "0.2.3",
      "resolved": "https://registry.npmjs.org/@firebase/auth-interop-types/-/auth-interop-types-0.2.3.tgz",
      "integrity": "sha512-Fc9wuJGgxoxQeavybiuwgyi+0rssr76b+nHpj+eGhXFYAdudMWyfBHvFL/I5fEHniUM/UQdFzi9VXJK2iZF7FQ==",
      "license": "Apache-2.0"
    },
    "node_modules/@firebase/component": {
      "version": "0.6.9",
      "resolved": "https://registry.npmjs.org/@firebase/component/-/component-0.6.9.tgz",
      "integrity": "sha512-gm8EUEJE/fEac86AvHn8Z/QW8BvR56TBw3hMW0O838J/1mThYQXAIQBgUv75EqlCZfdawpWLrKt1uXvp9ciK3Q==",
      "license": "Apache-2.0",
      "dependencies": {
        "@firebase/util": "1.10.0",
        "tslib": "^2.1.0"
      }
    },
    "node_modules/@firebase/database": {
      "version": "1.0.8",
      "resolved": "https://registry.npmjs.org/@firebase/database/-/database-1.0.8.tgz",
      "integrity": "sha512-dzXALZeBI1U5TXt6619cv0+tgEhJiwlUtQ55WNZY7vGAjv7Q1QioV969iYwt1AQQ0ovHnEW0YW9TiBfefLvErg==",
      "license": "Apache-2.0",
      "dependencies": {
        "@firebase/app-check-interop-types": "0.3.2",
        "@firebase/auth-interop-types": "0.2.3",
        "@firebase/component": "0.6.9",
        "@firebase/logger": "0.4.2",
        "@firebase/util": "1.10.0",
        "faye-websocket": "0.11.4",
        "tslib": "^2.1.0"
      }
    },
    "node_modules/@firebase/database-compat": {
      "version": "1.0.8",
      "resolved": "https://registry.npmjs.org/@firebase/database-compat/-/database-compat-1.0.8.tgz",
      "integrity": "sha512-OpeWZoPE3sGIRPBKYnW9wLad25RaWbGyk7fFQe4xnJQKRzlynWeFBSRRAoLE2Old01WXwskUiucNqUUVlFsceg==",
      "license": "Apache-2.0",
      "dependencies": {
        "@firebase/component": "0.6.9",
        "@firebase/database": "1.0.8",
        "@firebase/database-types": "1.0.5",
        "@firebase/logger": "0.4.2",
        "@firebase/util": "1.10.0",
        "tslib": "^2.1.0"
      }
    },
    "node_modules/@firebase/database-types": {
      "version": "1.0.5",
      "resolved": "https://registry.npmjs.org/@firebase/database-types/-/database-types-1.0.5.tgz",
      "integrity": "sha512-fTlqCNwFYyq/C6W7AJ5OCuq5CeZuBEsEwptnVxlNPkWCo5cTTyukzAHRSO/jaQcItz33FfYrrFk1SJofcu2AaQ==",
      "license": "Apache-2.0",
      "dependencies": {
        "@firebase/app-types": "0.9.2",
        "@firebase/util": "1.10.0"
      }
    },
    "node_modules/@firebase/logger": {
      "version": "0.4.2",
      "resolved": "https://registry.npmjs.org/@firebase/logger/-/logger-0.4.2.tgz",
      "integrity": "sha512-Q1VuA5M1Gjqrwom6I6NUU4lQXdo9IAQieXlujeHZWvRt1b7qQ0KwBaNAjgxG27jgF9/mUwsNmO8ptBCGVYhB0A==",
      "license": "Apache-2.0",
      "dependencies": {
        "tslib": "^2.1.0"
      }
    },
    "node_modules/@firebase/util": {
      "version": "1.10.0",
      "resolved": "https://registry.npmjs.org/@firebase/util/-/util-1.10.0.tgz",
      "integrity": "sha512-xKtx4A668icQqoANRxyDLBLz51TAbDP9KRfpbKGxiCAW346d0BeJe5vN6/hKxxmWwnZ0mautyv39JxviwwQMOQ==",
      "license": "Apache-2.0",
      "dependencies": {
        "tslib": "^2.1.0"
      }
    },
    "node_modules/@google-cloud/firestore": {
      "version": "7.11.6",
      "resolved": "https://registry.npmjs.org/@google-cloud/firestore/-/firestore-7.11.6.tgz",
      "integrity": "sha512-EW/O8ktzwLfyWBOsNuhRoMi8lrC3clHM5LVFhGvO1HCsLozCOOXRAlHrYBoE6HL42Sc8yYMuCb2XqcnJ4OOEpw==",
      "license": "Apache-2.0",
      "optional": true,
      "dependencies": {
        "@opentelemetry/api": "^1.3.0",
        "fast-deep-equal": "^3.1.1",
        "functional-red-black-tree": "^1.0.1",
        "google-gax": "^4.3.3",
        "protobufjs": "^7.2.6"
      },
      "engines": {
        "node": ">=14.0.0"
      }
    },
    "node_modules/@google-cloud/paginator": {
      "version": "5.0.2",
      "resolved": "https://registry.npmjs.org/@google-cloud/paginator/-/paginator-5.0.2.tgz",
      "integrity": "sha512-DJS3s0OVH4zFDB1PzjxAsHqJT6sKVbRwwML0ZBP9PbU7Yebtu/7SWMRzvO2J3nUi9pRNITCfu4LJeooM2w4pjg==",
      "license": "Apache-2.0",
      "optional": true,
      "dependencies": {
        "arrify": "^2.0.0",
        "extend": "^3.0.2"
      },
      "engines": {
        "node": ">=14.0.0"
      }
    },
    "node_modules/@google-cloud/projectify": {
      "version": "4.0.0",
      "resolved": "https://registry.npmjs.org/@google-cloud/projectify/-/projectify-4.0.0.tgz",
      "integrity": "sha512-MmaX6HeSvyPbWGwFq7mXdo0uQZLGBYCwziiLIGq5JVX+/bdI3SAq6bP98trV5eTWfLuvsMcIC1YJOF2vfteLFA==",
      "license": "Apache-2.0",
      "optional": true,
      "engines": {
        "node": ">=14.0.0"
      }
    },
    "node_modules/@google-cloud/promisify": {
      "version": "4.0.0",
      "resolved": "https://registry.npmjs.org/@google-cloud/promisify/-/promisify-4.0.0.tgz",
      "integrity": "sha512-Orxzlfb9c67A15cq2JQEyVc7wEsmFBmHjZWZYQMUyJ1qivXyMwdyNOs9odi79hze+2zqdTtu1E19IM/FtqZ10g==",
      "license": "Apache-2.0",
      "optional": true,
      "engines": {
        "node": ">=14"
      }
    },
    "node_modules/@google-cloud/storage": {
      "version": "7.19.0",
      "resolved": "https://registry.npmjs.org/@google-cloud/storage/-/storage-7.19.0.tgz",
      "integrity": "sha512-n2FjE7NAOYyshogdc7KQOl/VZb4sneqPjWouSyia9CMDdMhRX5+RIbqalNmC7LOLzuLAN89VlF2HvG8na9G+zQ==",
      "license": "Apache-2.0",
      "optional": true,
      "dependencies": {
        "@google-cloud/paginator": "^5.0.0",
        "@google-cloud/projectify": "^4.0.0",
        "@google-cloud/promisify": "<4.1.0",
        "abort-controller": "^3.0.0",
        "async-retry": "^1.3.3",
        "duplexify": "^4.1.3",
        "fast-xml-parser": "^5.3.4",
        "gaxios": "^6.0.2",
        "google-auth-library": "^9.6.3",
        "html-entities": "^2.5.2",
        "mime": "^3.0.0",
        "p-limit": "^3.0.1",
        "retry-request": "^7.0.0",
        "teeny-request": "^9.0.0",
        "uuid": "^8.0.0"
      },
      "engines": {
        "node": ">=14"
      }
    },
    "node_modules/@google-cloud/storage/node_modules/uuid": {
      "version": "8.3.2",
      "resolved": "https://registry.npmjs.org/uuid/-/uuid-8.3.2.tgz",
      "integrity": "sha512-+NYs2QeMWy+GWFOEm9xnn6HCDp0l7QBD7ml8zLUmJ+93Q5NF0NocErnwkTkXVFNiX3/fpC6afS8Dhb/gz7R7eg==",
      "license": "MIT",
      "optional": true,
      "bin": {
        "uuid": "dist/bin/uuid"
      }
    },
    "node_modules/@grpc/grpc-js": {
      "version": "1.14.3",
      "resolved": "https://registry.npmjs.org/@grpc/grpc-js/-/grpc-js-1.14.3.tgz",
      "integrity": "sha512-Iq8QQQ/7X3Sac15oB6p0FmUg/klxQvXLeileoqrTRGJYLV+/9tubbr9ipz0GKHjmXVsgFPo/+W+2cA8eNcR+XA==",
      "license": "Apache-2.0",
      "optional": true,
      "dependencies": {
        "@grpc/proto-loader": "^0.8.0",
        "@js-sdsl/ordered-map": "^4.4.2"
      },
      "engines": {
        "node": ">=12.10.0"
      }
    },
    "node_modules/@grpc/grpc-js/node_modules/@grpc/proto-loader": {
      "version": "0.8.0",
      "resolved": "https://registry.npmjs.org/@grpc/proto-loader/-/proto-loader-0.8.0.tgz",
      "integrity": "sha512-rc1hOQtjIWGxcxpb9aHAfLpIctjEnsDehj0DAiVfBlmT84uvR0uUtN2hEi/ecvWVjXUGf5qPF4qEgiLOx1YIMQ==",
      "license": "Apache-2.0",
      "optional": true,
      "dependencies": {
        "lodash.camelcase": "^4.3.0",
        "long": "^5.0.0",
        "protobufjs": "^7.5.3",
        "yargs": "^17.7.2"
      },
      "bin": {
        "proto-loader-gen-types": "build/bin/proto-loader-gen-types.js"
      },
      "engines": {
        "node": ">=6"
      }
    },
    "node_modules/@grpc/proto-loader": {
      "version": "0.7.15",
      "resolved": "https://registry.npmjs.org/@grpc/proto-loader/-/proto-loader-0.7.15.tgz",
      "integrity": "sha512-tMXdRCfYVixjuFK+Hk0Q1s38gV9zDiDJfWL3h1rv4Qc39oILCu1TRTDt7+fGUI8K4G1Fj125Hx/ru3azECWTyQ==",
      "license": "Apache-2.0",
      "optional": true,
      "dependencies": {
        "lodash.camelcase": "^4.3.0",
        "long": "^5.0.0",
        "protobufjs": "^7.2.5",
        "yargs": "^17.7.2"
      },
      "bin": {
        "proto-loader-gen-types": "build/bin/proto-loader-gen-types.js"
      },
      "engines": {
        "node": ">=6"
      }
    },
    "node_modules/@js-sdsl/ordered-map": {
      "version": "4.4.2",
      "resolved": "https://registry.npmjs.org/@js-sdsl/ordered-map/-/ordered-map-4.4.2.tgz",
      "integrity": "sha512-iUKgm52T8HOE/makSxjqoWhe95ZJA1/G1sYsGev2JDKUSS14KAgg1LHb+Ba+IPow0xflbnSkOsZcO08C7w1gYw==",
      "license": "MIT",
      "optional": true,
      "funding": {
        "type": "opencollective",
        "url": "https://opencollective.com/js-sdsl"
      }
    },
    "node_modules/@opentelemetry/api": {
      "version": "1.9.0",
      "resolved": "https://registry.npmjs.org/@opentelemetry/api/-/api-1.9.0.tgz",
      "integrity": "sha512-3giAOQvZiH5F9bMlMiv8+GSPMeqg0dbaeo58/0SlA9sxSqZhnUtxzX9/2FzyhS9sWQf5S0GJE0AKBrFqjpeYcg==",
      "license": "Apache-2.0",
      "optional": true,
      "engines": {
        "node": ">=8.0.0"
      }
    },
    "node_modules/@protobufjs/aspromise": {
      "version": "1.1.2",
      "resolved": "https://registry.npmjs.org/@protobufjs/aspromise/-/aspromise-1.1.2.tgz",
      "integrity": "sha512-j+gKExEuLmKwvz3OgROXtrJ2UG2x8Ch2YZUxahh+s1F2HZ+wAceUNLkvy6zKCPVRkU++ZWQrdxsUeQXmcg4uoQ==",
      "license": "BSD-3-Clause"
    },
    "node_modules/@protobufjs/base64": {
      "version": "1.1.2",
      "resolved": "https://registry.npmjs.org/@protobufjs/base64/-/base64-1.1.2.tgz",
      "integrity": "sha512-AZkcAA5vnN/v4PDqKyMR5lx7hZttPDgClv83E//FMNhR2TMcLUhfRUBHCmSl0oi9zMgDDqRUJkSxO3wm85+XLg==",
      "license": "BSD-3-Clause"
    },
    "node_modules/@protobufjs/codegen": {
      "version": "2.0.4",
      "resolved": "https://registry.npmjs.org/@protobufjs/codegen/-/codegen-2.0.4.tgz",
      "integrity": "sha512-YyFaikqM5sH0ziFZCN3xDC7zeGaB/d0IUb9CATugHWbd1FRFwWwt4ld4OYMPWu5a3Xe01mGAULCdqhMlPl29Jg==",
      "license": "BSD-3-Clause"
    },
    "node_modules/@protobufjs/eventemitter": {
      "version": "1.1.0",
      "resolved": "https://registry.npmjs.org/@protobufjs/eventemitter/-/eventemitter-1.1.0.tgz",
      "integrity": "sha512-j9ednRT81vYJ9OfVuXG6ERSTdEL1xVsNgqpkxMsbIabzSo3goCjDIveeGv5d03om39ML71RdmrGNjG5SReBP/Q==",
      "license": "BSD-3-Clause"
    },
    "node_modules/@protobufjs/fetch": {
      "version": "1.1.0",
      "resolved": "https://registry.npmjs.org/@protobufjs/fetch/-/fetch-1.1.0.tgz",
      "integrity": "sha512-lljVXpqXebpsijW71PZaCYeIcE5on1w5DlQy5WH6GLbFryLUrBD4932W/E2BSpfRJWseIL4v/KPgBFxDOIdKpQ==",
      "license": "BSD-3-Clause",
      "dependencies": {
        "@protobufjs/aspromise": "^1.1.1",
        "@protobufjs/inquire": "^1.1.0"
      }
    },
    "node_modules/@protobufjs/float": {
      "version": "1.0.2",
      "resolved": "https://registry.npmjs.org/@protobufjs/float/-/float-1.0.2.tgz",
      "integrity": "sha512-Ddb+kVXlXst9d+R9PfTIxh1EdNkgoRe5tOX6t01f1lYWOvJnSPDBlG241QLzcyPdoNTsblLUdujGSE4RzrTZGQ==",
      "license": "BSD-3-Clause"
    },
    "node_modules/@protobufjs/inquire": {
      "version": "1.1.0",
      "resolved": "https://registry.npmjs.org/@protobufjs/inquire/-/inquire-1.1.0.tgz",
      "integrity": "sha512-kdSefcPdruJiFMVSbn801t4vFK7KB/5gd2fYvrxhuJYg8ILrmn9SKSX2tZdV6V+ksulWqS7aXjBcRXl3wHoD9Q==",
      "license": "BSD-3-Clause"
    },
    "node_modules/@protobufjs/path": {
      "version": "1.1.2",
      "resolved": "https://registry.npmjs.org/@protobufjs/path/-/path-1.1.2.tgz",
      "integrity": "sha512-6JOcJ5Tm08dOHAbdR3GrvP+yUUfkjG5ePsHYczMFLq3ZmMkAD98cDgcT2iA1lJ9NVwFd4tH/iSSoe44YWkltEA==",
      "license": "BSD-3-Clause"
    },
    "node_modules/@protobufjs/pool": {
      "version": "1.1.0",
      "resolved": "https://registry.npmjs.org/@protobufjs/pool/-/pool-1.1.0.tgz",
      "integrity": "sha512-0kELaGSIDBKvcgS4zkjz1PeddatrjYcmMWOlAuAPwAeccUrPHdUqo/J6LiymHHEiJT5NrF1UVwxY14f+fy4WQw==",
      "license": "BSD-3-Clause"
    },
    "node_modules/@protobufjs/utf8": {
      "version": "1.1.0",
      "resolved": "https://registry.npmjs.org/@protobufjs/utf8/-/utf8-1.1.0.tgz",
      "integrity": "sha512-Vvn3zZrhQZkkBE8LSuW3em98c0FwgO4nxzv6OdSxPKJIEKY2bGbHn+mhGIPerzI4twdxaP8/0+06HBpwf345Lw==",
      "license": "BSD-3-Clause"
    },
    "node_modules/@sendgrid/client": {
      "version": "8.1.6",
      "resolved": "https://registry.npmjs.org/@sendgrid/client/-/client-8.1.6.tgz",
      "integrity": "sha512-/BHu0hqwXNHr2aLhcXU7RmmlVqrdfrbY9KpaNj00KZHlVOVoRxRVrpOCabIB+91ISXJ6+mLM9vpaVUhK6TwBWA==",
      "license": "MIT",
      "dependencies": {
        "@sendgrid/helpers": "^8.0.0",
        "axios": "^1.12.0"
      },
      "engines": {
        "node": ">=12.*"
      }
    },
    "node_modules/@sendgrid/helpers": {
      "version": "8.0.0",
      "resolved": "https://registry.npmjs.org/@sendgrid/helpers/-/helpers-8.0.0.tgz",
      "integrity": "sha512-Ze7WuW2Xzy5GT5WRx+yEv89fsg/pgy3T1E3FS0QEx0/VvRmigMZ5qyVGhJz4SxomegDkzXv/i0aFPpHKN8qdAA==",
      "license": "MIT",
      "dependencies": {
        "deepmerge": "^4.2.2"
      },
      "engines": {
        "node": ">= 12.0.0"
      }
    },
    "node_modules/@sendgrid/mail": {
      "version": "8.1.6",
      "resolved": "https://registry.npmjs.org/@sendgrid/mail/-/mail-8.1.6.tgz",
      "integrity": "sha512-/ZqxUvKeEztU9drOoPC/8opEPOk+jLlB2q4+xpx6HVLq6aFu3pMpalkTpAQz8XfRfpLp8O25bh6pGPcHDCYpqg==",
      "license": "MIT",
      "dependencies": {
        "@sendgrid/client": "^8.1.5",
        "@sendgrid/helpers": "^8.0.0"
      },
      "engines": {
        "node": ">=12.*"
      }
    },
    "node_modules/@tootallnate/once": {
      "version": "2.0.0",
      "resolved": "https://registry.npmjs.org/@tootallnate/once/-/once-2.0.0.tgz",
      "integrity": "sha512-XCuKFP5PS55gnMVu3dty8KPatLqUoy/ZYzDzAGCQ8JNFCkLXzmI7vNHCR+XpbZaMWQK/vQubr7PkYq8g470J/A==",
      "license": "MIT",
      "optional": true,
      "engines": {
        "node": ">= 10"
      }
    },
    "node_modules/@types/body-parser": {
      "version": "1.19.6",
      "resolved": "https://registry.npmjs.org/@types/body-parser/-/body-parser-1.19.6.tgz",
      "integrity": "sha512-HLFeCYgz89uk22N5Qg3dvGvsv46B8GLvKKo1zKG4NybA8U2DiEO3w9lqGg29t/tfLRJpJ6iQxnVw4OnB7MoM9g==",
      "license": "MIT",
      "dependencies": {
        "@types/connect": "*",
        "@types/node": "*"
      }
    },
    "node_modules/@types/caseless": {
      "version": "0.12.5",
      "resolved": "https://registry.npmjs.org/@types/caseless/-/caseless-0.12.5.tgz",
      "integrity": "sha512-hWtVTC2q7hc7xZ/RLbxapMvDMgUnDvKvMOpKal4DrMyfGBUfB1oKaZlIRr6mJL+If3bAP6sV/QneGzF6tJjZDg==",
      "license": "MIT",
      "optional": true
    },
    "node_modules/@types/connect": {
      "version": "3.4.38",
      "resolved": "https://registry.npmjs.org/@types/connect/-/connect-3.4.38.tgz",
      "integrity": "sha512-K6uROf1LD88uDQqJCktA4yzL1YYAK6NgfsI0v/mTgyPKWsX1CnJ0XPSDhViejru1GcRkLWb8RlzFYJRqGUbaug==",
      "license": "MIT",
      "dependencies": {
        "@types/node": "*"
      }
    },
    "node_modules/@types/cors": {
      "version": "2.8.19",
      "resolved": "https://registry.npmjs.org/@types/cors/-/cors-2.8.19.tgz",
      "integrity": "sha512-mFNylyeyqN93lfe/9CSxOGREz8cpzAhH+E93xJ4xWQf62V8sQ/24reV2nyzUWM6H6Xji+GGHpkbLe7pVoUEskg==",
      "license": "MIT",
      "dependencies": {
        "@types/node": "*"
      }
    },
    "node_modules/@types/express": {
      "version": "4.17.3",
      "resolved": "https://registry.npmjs.org/@types/express/-/express-4.17.3.tgz",
      "integrity": "sha512-I8cGRJj3pyOLs/HndoP+25vOqhqWkAZsWMEmq1qXy/b/M3ppufecUwaK2/TVDVxcV61/iSdhykUjQQ2DLSrTdg==",
      "license": "MIT",
      "dependencies": {
        "@types/body-parser": "*",
        "@types/express-serve-static-core": "*",
        "@types/serve-static": "*"
      }
    },
    "node_modules/@types/express-serve-static-core": {
      "version": "5.1.1",
      "resolved": "https://registry.npmjs.org/@types/express-serve-static-core/-/express-serve-static-core-5.1.1.tgz",
      "integrity": "sha512-v4zIMr/cX7/d2BpAEX3KNKL/JrT1s43s96lLvvdTmza1oEvDudCqK9aF/djc/SWgy8Yh0h30TZx5VpzqFCxk5A==",
      "license": "MIT",
      "dependencies": {
        "@types/node": "*",
        "@types/qs": "*",
        "@types/range-parser": "*",
        "@types/send": "*"
      }
    },
    "node_modules/@types/http-errors": {
      "version": "2.0.5",
      "resolved": "https://registry.npmjs.org/@types/http-errors/-/http-errors-2.0.5.tgz",
      "integrity": "sha512-r8Tayk8HJnX0FztbZN7oVqGccWgw98T/0neJphO91KkmOzug1KkofZURD4UaD5uH8AqcFLfdPErnBod0u71/qg==",
      "license": "MIT"
    },
    "node_modules/@types/jsonwebtoken": {
      "version": "9.0.10",
      "resolved": "https://registry.npmjs.org/@types/jsonwebtoken/-/jsonwebtoken-9.0.10.tgz",
      "integrity": "sha512-asx5hIG9Qmf/1oStypjanR7iKTv0gXQ1Ov/jfrX6kS/EO0OFni8orbmGCn0672NHR3kXHwpAwR+B368ZGN/2rA==",
      "license": "MIT",
      "dependencies": {
        "@types/ms": "*",
        "@types/node": "*"
      }
    },
    "node_modules/@types/long": {
      "version": "4.0.2",
      "resolved": "https://registry.npmjs.org/@types/long/-/long-4.0.2.tgz",
      "integrity": "sha512-MqTGEo5bj5t157U6fA/BiDynNkn0YknVdh48CMPkTSpFTVmvao5UQmm7uEF6xBEo7qIMAlY/JSleYaE6VOdpaA==",
      "license": "MIT",
      "optional": true
    },
    "node_modules/@types/ms": {
      "version": "2.1.0",
      "resolved": "https://registry.npmjs.org/@types/ms/-/ms-2.1.0.tgz",
      "integrity": "sha512-GsCCIZDE/p3i96vtEqx+7dBUGXrc7zeSK3wwPHIaRThS+9OhWIXRqzs4d6k1SVU8g91DrNRWxWUGhp5KXQb2VA==",
      "license": "MIT"
    },
    "node_modules/@types/node": {
      "version": "22.19.10",
      "resolved": "https://registry.npmjs.org/@types/node/-/node-22.19.10.tgz",
      "integrity": "sha512-tF5VOugLS/EuDlTBijk0MqABfP8UxgYazTLo3uIn3b4yJgg26QRbVYJYsDtHrjdDUIRfP70+VfhTTc+CE1yskw==",
      "license": "MIT",
      "dependencies": {
        "undici-types": "~6.21.0"
      }
    },
    "node_modules/@types/qs": {
      "version": "6.14.0",
      "resolved": "https://registry.npmjs.org/@types/qs/-/qs-6.14.0.tgz",
      "integrity": "sha512-eOunJqu0K1923aExK6y8p6fsihYEn/BYuQ4g0CxAAgFc4b/ZLN4CrsRZ55srTdqoiLzU2B2evC+apEIxprEzkQ==",
      "license": "MIT"
    },
    "node_modules/@types/range-parser": {
      "version": "1.2.7",
      "resolved": "https://registry.npmjs.org/@types/range-parser/-/range-parser-1.2.7.tgz",
      "integrity": "sha512-hKormJbkJqzQGhziax5PItDUTMAM9uE2XXQmM37dyd4hVM+5aVl7oVxMVUiVQn2oCQFN/LKCZdvSM0pFRqbSmQ==",
      "license": "MIT"
    },
    "node_modules/@types/request": {
      "version": "2.48.13",
      "resolved": "https://registry.npmjs.org/@types/request/-/request-2.48.13.tgz",
      "integrity": "sha512-FGJ6udDNUCjd19pp0Q3iTiDkwhYup7J8hpMW9c4k53NrccQFFWKRho6hvtPPEhnXWKvukfwAlB6DbDz4yhH5Gg==",
      "license": "MIT",
      "optional": true,
      "dependencies": {
        "@types/caseless": "*",
        "@types/node": "*",
        "@types/tough-cookie": "*",
        "form-data": "^2.5.5"
      }
    },
    "node_modules/@types/request/node_modules/form-data": {
      "version": "2.5.5",
      "resolved": "https://registry.npmjs.org/form-data/-/form-data-2.5.5.tgz",
      "integrity": "sha512-jqdObeR2rxZZbPSGL+3VckHMYtu+f9//KXBsVny6JSX/pa38Fy+bGjuG8eW/H6USNQWhLi8Num++cU2yOCNz4A==",
      "license": "MIT",
      "optional": true,
      "dependencies": {
        "asynckit": "^0.4.0",
        "combined-stream": "^1.0.8",
        "es-set-tostringtag": "^2.1.0",
        "hasown": "^2.0.2",
        "mime-types": "^2.1.35",
        "safe-buffer": "^5.2.1"
      },
      "engines": {
        "node": ">= 0.12"
      }
    },
    "node_modules/@types/send": {
      "version": "1.2.1",
      "resolved": "https://registry.npmjs.org/@types/send/-/send-1.2.1.tgz",
      "integrity": "sha512-arsCikDvlU99zl1g69TcAB3mzZPpxgw0UQnaHeC1Nwb015xp8bknZv5rIfri9xTOcMuaVgvabfIRA7PSZVuZIQ==",
      "license": "MIT",
      "dependencies": {
        "@types/node": "*"
      }
    },
    "node_modules/@types/serve-static": {
      "version": "2.2.0",
      "resolved": "https://registry.npmjs.org/@types/serve-static/-/serve-static-2.2.0.tgz",
      "integrity": "sha512-8mam4H1NHLtu7nmtalF7eyBH14QyOASmcxHhSfEoRyr0nP/YdoesEtU+uSRvMe96TW/HPTtkoKqQLl53N7UXMQ==",
      "license": "MIT",
      "dependencies": {
        "@types/http-errors": "*",
        "@types/node": "*"
      }
    },
    "node_modules/@types/tough-cookie": {
      "version": "4.0.5",
      "resolved": "https://registry.npmjs.org/@types/tough-cookie/-/tough-cookie-4.0.5.tgz",
      "integrity": "sha512-/Ad8+nIOV7Rl++6f1BdKxFSMgmoqEoYbHRpPcx3JEfv8VRsQe9Z4mCXeJBzxs7mbHY/XOZZuXlRNfhpVPbs6ZA==",
      "license": "MIT",
      "optional": true
    },
    "node_modules/abort-controller": {
      "version": "3.0.0",
      "resolved": "https://registry.npmjs.org/abort-controller/-/abort-controller-3.0.0.tgz",
      "integrity": "sha512-h8lQ8tacZYnR3vNQTgibj+tODHI5/+l06Au2Pcriv/Gmet0eaj4TwWH41sO9wnHDiQsEj19q0drzdWdeAHtweg==",
      "license": "MIT",
      "optional": true,
      "dependencies": {
        "event-target-shim": "^5.0.0"
      },
      "engines": {
        "node": ">=6.5"
      }
    },
    "node_modules/accepts": {
      "version": "1.3.8",
      "resolved": "https://registry.npmjs.org/accepts/-/accepts-1.3.8.tgz",
      "integrity": "sha512-PYAthTa2m2VKxuvSD3DPC/Gy+U+sOA1LAuT8mkmRuvw+NACSaeXEQ+NHcVF7rONl6qcaxV3Uuemwawk+7+SJLw==",
      "license": "MIT",
      "dependencies": {
        "mime-types": "~2.1.34",
        "negotiator": "0.6.3"
      },
      "engines": {
        "node": ">= 0.6"
      }
    },
    "node_modules/agent-base": {
      "version": "7.1.4",
      "resolved": "https://registry.npmjs.org/agent-base/-/agent-base-7.1.4.tgz",
      "integrity": "sha512-MnA+YT8fwfJPgBx3m60MNqakm30XOkyIoH1y6huTQvC0PwZG7ki8NacLBcrPbNoo8vEZy7Jpuk7+jMO+CUovTQ==",
      "license": "MIT",
      "optional": true,
      "engines": {
        "node": ">= 14"
      }
    },
    "node_modules/ansi-regex": {
      "version": "5.0.1",
      "resolved": "https://registry.npmjs.org/ansi-regex/-/ansi-regex-5.0.1.tgz",
      "integrity": "sha512-quJQXlTSUGL2LH9SUXo8VwsY4soanhgo6LNSm84E1LBcE8s3O0wpdiRzyR9z/ZZJMlMWv37qOOb9pdJlMUEKFQ==",
      "license": "MIT",
      "optional": true,
      "engines": {
        "node": ">=8"
      }
    },
    "node_modules/ansi-styles": {
      "version": "4.3.0",
      "resolved": "https://registry.npmjs.org/ansi-styles/-/ansi-styles-4.3.0.tgz",
      "integrity": "sha512-zbB9rCJAT1rbjiVDb2hqKFHNYLxgtk8NURxZ3IZwD3F6NtxbXZQCnnSi1Lkx+IDohdPlFp222wVALIheZJQSEg==",
      "license": "MIT",
      "optional": true,
      "dependencies": {
        "color-convert": "^2.0.1"
      },
      "engines": {
        "node": ">=8"
      },
      "funding": {
        "url": "https://github.com/chalk/ansi-styles?sponsor=1"
      }
    },
    "node_modules/array-flatten": {
      "version": "1.1.1",
      "resolved": "https://registry.npmjs.org/array-flatten/-/array-flatten-1.1.1.tgz",
      "integrity": "sha512-PCVAQswWemu6UdxsDFFX/+gVeYqKAod3D3UVm91jHwynguOwAvYPhx8nNlM++NqRcK6CxxpUafjmhIdKiHibqg==",
      "license": "MIT"
    },
    "node_modules/arrify": {
      "version": "2.0.1",
      "resolved": "https://registry.npmjs.org/arrify/-/arrify-2.0.1.tgz",
      "integrity": "sha512-3duEwti880xqi4eAMN8AyR4a0ByT90zoYdLlevfrvU43vb0YZwZVfxOgxWrLXXXpyugL0hNZc9G6BiB5B3nUug==",
      "license": "MIT",
      "optional": true,
      "engines": {
        "node": ">=8"
      }
    },
    "node_modules/async-retry": {
      "version": "1.3.3",
      "resolved": "https://registry.npmjs.org/async-retry/-/async-retry-1.3.3.tgz",
      "integrity": "sha512-wfr/jstw9xNi/0teMHrRW7dsz3Lt5ARhYNZ2ewpadnhaIp5mbALhOAP+EAdsC7t4Z6wqsDVv9+W6gm1Dk9mEyw==",
      "license": "MIT",
      "optional": true,
      "dependencies": {
        "retry": "0.13.1"
      }
    },
    "node_modules/asynckit": {
      "version": "0.4.0",
      "resolved": "https://registry.npmjs.org/asynckit/-/asynckit-0.4.0.tgz",
      "integrity": "sha512-Oei9OH4tRh0YqU3GxhX79dM/mwVgvbZJaSNaRk+bshkj0S5cfHcgYakreBjrHwatXKbz+IoIdYLxrKim2MjW0Q==",
      "license": "MIT"
    },
    "node_modules/axios": {
      "version": "1.13.5",
      "resolved": "https://registry.npmjs.org/axios/-/axios-1.13.5.tgz",
      "integrity": "sha512-cz4ur7Vb0xS4/KUN0tPWe44eqxrIu31me+fbang3ijiNscE129POzipJJA6zniq2C/Z6sJCjMimjS8Lc/GAs8Q==",
      "license": "MIT",
      "dependencies": {
        "follow-redirects": "^1.15.11",
        "form-data": "^4.0.5",
        "proxy-from-env": "^1.1.0"
      }
    },
    "node_modules/base64-js": {
      "version": "1.5.1",
      "resolved": "https://registry.npmjs.org/base64-js/-/base64-js-1.5.1.tgz",
      "integrity": "sha512-AKpaYlHn8t4SVbOHCy+b5+KKgvR4vrsD8vbvrbiQJps7fKDTkjkDry6ji0rUJjC0kzbNePLwzxq8iypo41qeWA==",
      "funding": [
        {
          "type": "github",
          "url": "https://github.com/sponsors/feross"
        },
        {
          "type": "patreon",
          "url": "https://www.patreon.com/feross"
        },
        {
          "type": "consulting",
          "url": "https://feross.org/support"
        }
      ],
      "license": "MIT",
      "optional": true
    },
    "node_modules/bignumber.js": {
      "version": "9.3.1",
      "resolved": "https://registry.npmjs.org/bignumber.js/-/bignumber.js-9.3.1.tgz",
      "integrity": "sha512-Ko0uX15oIUS7wJ3Rb30Fs6SkVbLmPBAKdlm7q9+ak9bbIeFf0MwuBsQV6z7+X768/cHsfg+WlysDWJcmthjsjQ==",
      "license": "MIT",
      "optional": true,
      "engines": {
        "node": "*"
      }
    },
    "node_modules/body-parser": {
      "version": "1.20.4",
      "resolved": "https://registry.npmjs.org/body-parser/-/body-parser-1.20.4.tgz",
      "integrity": "sha512-ZTgYYLMOXY9qKU/57FAo8F+HA2dGX7bqGc71txDRC1rS4frdFI5R7NhluHxH6M0YItAP0sHB4uqAOcYKxO6uGA==",
      "license": "MIT",
      "dependencies": {
        "bytes": "~3.1.2",
        "content-type": "~1.0.5",
        "debug": "2.6.9",
        "depd": "2.0.0",
        "destroy": "~1.2.0",
        "http-errors": "~2.0.1",
        "iconv-lite": "~0.4.24",
        "on-finished": "~2.4.1",
        "qs": "~6.14.0",
        "raw-body": "~2.5.3",
        "type-is": "~1.6.18",
        "unpipe": "~1.0.0"
      },
      "engines": {
        "node": ">= 0.8",
        "npm": "1.2.8000 || >= 1.4.16"
      }
    },
    "node_modules/buffer-equal-constant-time": {
      "version": "1.0.1",
      "resolved": "https://registry.npmjs.org/buffer-equal-constant-time/-/buffer-equal-constant-time-1.0.1.tgz",
      "integrity": "sha512-zRpUiDwd/xk6ADqPMATG8vc9VPrkck7T07OIx0gnjmJAnHnTVXNQG3vfvWNuiZIkwu9KrKdA1iJKfsfTVxE6NA==",
      "license": "BSD-3-Clause"
    },
    "node_modules/bytes": {
      "version": "3.1.2",
      "resolved": "https://registry.npmjs.org/bytes/-/bytes-3.1.2.tgz",
      "integrity": "sha512-/Nf7TyzTx6S3yRJObOAV7956r8cr2+Oj8AC5dt8wSP3BQAoeX58NoHyCU8P8zGkNXStjTSi6fzO6F0pBdcYbEg==",
      "license": "MIT",
      "engines": {
        "node": ">= 0.8"
      }
    },
    "node_modules/call-bind-apply-helpers": {
      "version": "1.0.2",
      "resolved": "https://registry.npmjs.org/call-bind-apply-helpers/-/call-bind-apply-helpers-1.0.2.tgz",
      "integrity": "sha512-Sp1ablJ0ivDkSzjcaJdxEunN5/XvksFJ2sMBFfq6x0ryhQV/2b/KwFe21cMpmHtPOSij8K99/wSfoEuTObmuMQ==",
      "license": "MIT",
      "dependencies": {
        "es-errors": "^1.3.0",
        "function-bind": "^1.1.2"
      },
      "engines": {
        "node": ">= 0.4"
      }
    },
    "node_modules/call-bound": {
      "version": "1.0.4",
      "resolved": "https://registry.npmjs.org/call-bound/-/call-bound-1.0.4.tgz",
      "integrity": "sha512-+ys997U96po4Kx/ABpBCqhA9EuxJaQWDQg7295H4hBphv3IZg0boBKuwYpt4YXp6MZ5AmZQnU/tyMTlRpaSejg==",
      "license": "MIT",
      "dependencies": {
        "call-bind-apply-helpers": "^1.0.2",
        "get-intrinsic": "^1.3.0"
      },
      "engines": {
        "node": ">= 0.4"
      },
      "funding": {
        "url": "https://github.com/sponsors/ljharb"
      }
    },
    "node_modules/cliui": {
      "version": "8.0.1",
      "resolved": "https://registry.npmjs.org/cliui/-/cliui-8.0.1.tgz",
      "integrity": "sha512-BSeNnyus75C4//NQ9gQt1/csTXyo/8Sb+afLAkzAptFuMsod9HFokGNudZpi/oQV73hnVK+sR+5PVRMd+Dr7YQ==",
      "license": "ISC",
      "optional": true,
      "dependencies": {
        "string-width": "^4.2.0",
        "strip-ansi": "^6.0.1",
        "wrap-ansi": "^7.0.0"
      },
      "engines": {
        "node": ">=12"
      }
    },
    "node_modules/color-convert": {
      "version": "2.0.1",
      "resolved": "https://registry.npmjs.org/color-convert/-/color-convert-2.0.1.tgz",
      "integrity": "sha512-RRECPsj7iu/xb5oKYcsFHSppFNnsj/52OVTRKb4zP5onXwVF3zVmmToNcOfGC+CRDpfK/U584fMg38ZHCaElKQ==",
      "license": "MIT",
      "optional": true,
      "dependencies": {
        "color-name": "~1.1.4"
      },
      "engines": {
        "node": ">=7.0.0"
      }
    },
    "node_modules/color-name": {
      "version": "1.1.4",
      "resolved": "https://registry.npmjs.org/color-name/-/color-name-1.1.4.tgz",
      "integrity": "sha512-dOy+3AuW3a2wNbZHIuMZpTcgjGuLU/uBL/ubcZF9OXbDo8ff4O8yVp5Bf0efS8uEoYo5q4Fx7dY9OgQGXgAsQA==",
      "license": "MIT",
      "optional": true
    },
    "node_modules/combined-stream": {
      "version": "1.0.8",
      "resolved": "https://registry.npmjs.org/combined-stream/-/combined-stream-1.0.8.tgz",
      "integrity": "sha512-FQN4MRfuJeHf7cBbBMJFXhKSDq+2kAArBlmRBvcvFE5BB1HZKXtSFASDhdlz9zOYwxh8lDdnvmMOe/+5cdoEdg==",
      "license": "MIT",
      "dependencies": {
        "delayed-stream": "~1.0.0"
      },
      "engines": {
        "node": ">= 0.8"
      }
    },
    "node_modules/content-disposition": {
      "version": "0.5.4",
      "resolved": "https://registry.npmjs.org/content-disposition/-/content-disposition-0.5.4.tgz",
      "integrity": "sha512-FveZTNuGw04cxlAiWbzi6zTAL/lhehaWbTtgluJh4/E95DqMwTmha3KZN1aAWA8cFIhHzMZUvLevkw5Rqk+tSQ==",
      "license": "MIT",
      "dependencies": {
        "safe-buffer": "5.2.1"
      },
      "engines": {
        "node": ">= 0.6"
      }
    },
    "node_modules/content-type": {
      "version": "1.0.5",
      "resolved": "https://registry.npmjs.org/content-type/-/content-type-1.0.5.tgz",
      "integrity": "sha512-nTjqfcBFEipKdXCv4YDQWCfmcLZKm81ldF0pAopTvyrFGVbcR6P/VAAd5G7N+0tTr8QqiU0tFadD6FK4NtJwOA==",
      "license": "MIT",
      "engines": {
        "node": ">= 0.6"
      }
    },
    "node_modules/cookie": {
      "version": "0.7.2",
      "resolved": "https://registry.npmjs.org/cookie/-/cookie-0.7.2.tgz",
      "integrity": "sha512-yki5XnKuf750l50uGTllt6kKILY4nQ1eNIQatoXEByZ5dWgnKqbnqmTrBE5B4N7lrMJKQ2ytWMiTO2o0v6Ew/w==",
      "license": "MIT",
      "engines": {
        "node": ">= 0.6"
      }
    },
    "node_modules/cookie-signature": {
      "version": "1.0.7",
      "resolved": "https://registry.npmjs.org/cookie-signature/-/cookie-signature-1.0.7.tgz",
      "integrity": "sha512-NXdYc3dLr47pBkpUCHtKSwIOQXLVn8dZEuywboCOJY/osA0wFSLlSawr3KN8qXJEyX66FcONTH8EIlVuK0yyFA==",
      "license": "MIT"
    },
    "node_modules/cors": {
      "version": "2.8.6",
      "resolved": "https://registry.npmjs.org/cors/-/cors-2.8.6.tgz",
      "integrity": "sha512-tJtZBBHA6vjIAaF6EnIaq6laBBP9aq/Y3ouVJjEfoHbRBcHBAHYcMh/w8LDrk2PvIMMq8gmopa5D4V8RmbrxGw==",
      "license": "MIT",
      "dependencies": {
        "object-assign": "^4",
        "vary": "^1"
      },
      "engines": {
        "node": ">= 0.10"
      },
      "funding": {
        "type": "opencollective",
        "url": "https://opencollective.com/express"
      }
    },
    "node_modules/dayjs": {
      "version": "1.11.19",
      "resolved": "https://registry.npmjs.org/dayjs/-/dayjs-1.11.19.tgz",
      "integrity": "sha512-t5EcLVS6QPBNqM2z8fakk/NKel+Xzshgt8FFKAn+qwlD1pzZWxh0nVCrvFK7ZDb6XucZeF9z8C7CBWTRIVApAw==",
      "license": "MIT"
    },
    "node_modules/debug": {
      "version": "2.6.9",
      "resolved": "https://registry.npmjs.org/debug/-/debug-2.6.9.tgz",
      "integrity": "sha512-bC7ElrdJaJnPbAP+1EotYvqZsb3ecl5wi6Bfi6BJTUcNowp6cvspg0jXznRTKDjm/E7AdgFBVeAPVMNcKGsHMA==",
      "license": "MIT",
      "dependencies": {
        "ms": "2.0.0"
      }
    },
    "node_modules/deepmerge": {
      "version": "4.3.1",
      "resolved": "https://registry.npmjs.org/deepmerge/-/deepmerge-4.3.1.tgz",
      "integrity": "sha512-3sUqbMEc77XqpdNO7FRyRog+eW3ph+GYCbj+rK+uYyRMuwsVy0rMiVtPn+QJlKFvWP/1PYpapqYn0Me2knFn+A==",
      "license": "MIT",
      "engines": {
        "node": ">=0.10.0"
      }
    },
    "node_modules/delayed-stream": {
      "version": "1.0.0",
      "resolved": "https://registry.npmjs.org/delayed-stream/-/delayed-stream-1.0.0.tgz",
      "integrity": "sha512-ZySD7Nf91aLB0RxL4KGrKHBXl7Eds1DAmEdcoVawXnLD7SDhpNgtuII2aAkg7a7QS41jxPSZ17p4VdGnMHk3MQ==",
      "license": "MIT",
      "engines": {
        "node": ">=0.4.0"
      }
    },
    "node_modules/depd": {
      "version": "2.0.0",
      "resolved": "https://registry.npmjs.org/depd/-/depd-2.0.0.tgz",
      "integrity": "sha512-g7nH6P6dyDioJogAAGprGpCtVImJhpPk/roCzdb3fIh61/s/nPsfR6onyMwkCAR/OlC3yBC0lESvUoQEAssIrw==",
      "license": "MIT",
      "engines": {
        "node": ">= 0.8"
      }
    },
    "node_modules/destroy": {
      "version": "1.2.0",
      "resolved": "https://registry.npmjs.org/destroy/-/destroy-1.2.0.tgz",
      "integrity": "sha512-2sJGJTaXIIaR1w4iJSNoN0hnMY7Gpc/n8D4qSCJw8QqFWXf7cuAgnEHxBpweaVcPevC2l3KpjYCx3NypQQgaJg==",
      "license": "MIT",
      "engines": {
        "node": ">= 0.8",
        "npm": "1.2.8000 || >= 1.4.16"
      }
    },
    "node_modules/dunder-proto": {
      "version": "1.0.1",
      "resolved": "https://registry.npmjs.org/dunder-proto/-/dunder-proto-1.0.1.tgz",
      "integrity": "sha512-KIN/nDJBQRcXw0MLVhZE9iQHmG68qAVIBg9CqmUYjmQIhgij9U5MFvrqkUL5FbtyyzZuOeOt0zdeRe4UY7ct+A==",
      "license": "MIT",
      "dependencies": {
        "call-bind-apply-helpers": "^1.0.1",
        "es-errors": "^1.3.0",
        "gopd": "^1.2.0"
      },
      "engines": {
        "node": ">= 0.4"
      }
    },
    "node_modules/duplexify": {
      "version": "4.1.3",
      "resolved": "https://registry.npmjs.org/duplexify/-/duplexify-4.1.3.tgz",
      "integrity": "sha512-M3BmBhwJRZsSx38lZyhE53Csddgzl5R7xGJNk7CVddZD6CcmwMCH8J+7AprIrQKH7TonKxaCjcv27Qmf+sQ+oA==",
      "license": "MIT",
      "optional": true,
      "dependencies": {
        "end-of-stream": "^1.4.1",
        "inherits": "^2.0.3",
        "readable-stream": "^3.1.1",
        "stream-shift": "^1.0.2"
      }
    },
    "node_modules/ecdsa-sig-formatter": {
      "version": "1.0.11",
      "resolved": "https://registry.npmjs.org/ecdsa-sig-formatter/-/ecdsa-sig-formatter-1.0.11.tgz",
      "integrity": "sha512-nagl3RYrbNv6kQkeJIpt6NJZy8twLB/2vtz6yN9Z4vRKHN4/QZJIEbqohALSgwKdnksuY3k5Addp5lg8sVoVcQ==",
      "license": "Apache-2.0",
      "dependencies": {
        "safe-buffer": "^5.0.1"
      }
    },
    "node_modules/ee-first": {
      "version": "1.1.1",
      "resolved": "https://registry.npmjs.org/ee-first/-/ee-first-1.1.1.tgz",
      "integrity": "sha512-WMwm9LhRUo+WUaRN+vRuETqG89IgZphVSNkdFgeb6sS/E4OrDIN7t48CAewSHXc6C8lefD8KKfr5vY61brQlow==",
      "license": "MIT"
    },
    "node_modules/emoji-regex": {
      "version": "8.0.0",
      "resolved": "https://registry.npmjs.org/emoji-regex/-/emoji-regex-8.0.0.tgz",
      "integrity": "sha512-MSjYzcWNOA0ewAHpz0MxpYFvwg6yjy1NG3xteoqz644VCo/RPgnr1/GGt+ic3iJTzQ8Eu3TdM14SawnVUmGE6A==",
      "license": "MIT",
      "optional": true
    },
    "node_modules/encodeurl": {
      "version": "2.0.0",
      "resolved": "https://registry.npmjs.org/encodeurl/-/encodeurl-2.0.0.tgz",
      "integrity": "sha512-Q0n9HRi4m6JuGIV1eFlmvJB7ZEVxu93IrMyiMsGC0lrMJMWzRgx6WGquyfQgZVb31vhGgXnfmPNNXmxnOkRBrg==",
      "license": "MIT",
      "engines": {
        "node": ">= 0.8"
      }
    },
    "node_modules/end-of-stream": {
      "version": "1.4.5",
      "resolved": "https://registry.npmjs.org/end-of-stream/-/end-of-stream-1.4.5.tgz",
      "integrity": "sha512-ooEGc6HP26xXq/N+GCGOT0JKCLDGrq2bQUZrQ7gyrJiZANJ/8YDTxTpQBXGMn+WbIQXNVpyWymm7KYVICQnyOg==",
      "license": "MIT",
      "optional": true,
      "dependencies": {
        "once": "^1.4.0"
      }
    },
    "node_modules/es-define-property": {
      "version": "1.0.1",
      "resolved": "https://registry.npmjs.org/es-define-property/-/es-define-property-1.0.1.tgz",
      "integrity": "sha512-e3nRfgfUZ4rNGL232gUgX06QNyyez04KdjFrF+LTRoOXmrOgFKDg4BCdsjW8EnT69eqdYGmRpJwiPVYNrCaW3g==",
      "license": "MIT",
      "engines": {
        "node": ">= 0.4"
      }
    },
    "node_modules/es-errors": {
      "version": "1.3.0",
      "resolved": "https://registry.npmjs.org/es-errors/-/es-errors-1.3.0.tgz",
      "integrity": "sha512-Zf5H2Kxt2xjTvbJvP2ZWLEICxA6j+hAmMzIlypy4xcBg1vKVnx89Wy0GbS+kf5cwCVFFzdCFh2XSCFNULS6csw==",
      "license": "MIT",
      "engines": {
        "node": ">= 0.4"
      }
    },
    "node_modules/es-object-atoms": {
      "version": "1.1.1",
      "resolved": "https://registry.npmjs.org/es-object-atoms/-/es-object-atoms-1.1.1.tgz",
      "integrity": "sha512-FGgH2h8zKNim9ljj7dankFPcICIK9Cp5bm+c2gQSYePhpaG5+esrLODihIorn+Pe6FGJzWhXQotPv73jTaldXA==",
      "license": "MIT",
      "dependencies": {
        "es-errors": "^1.3.0"
      },
      "engines": {
        "node": ">= 0.4"
      }
    },
    "node_modules/es-set-tostringtag": {
      "version": "2.1.0",
      "resolved": "https://registry.npmjs.org/es-set-tostringtag/-/es-set-tostringtag-2.1.0.tgz",
      "integrity": "sha512-j6vWzfrGVfyXxge+O0x5sh6cvxAog0a/4Rdd2K36zCMV5eJ+/+tOAngRO8cODMNWbVRdVlmGZQL2YS3yR8bIUA==",
      "license": "MIT",
      "dependencies": {
        "es-errors": "^1.3.0",
        "get-intrinsic": "^1.2.6",
        "has-tostringtag": "^1.0.2",
        "hasown": "^2.0.2"
      },
      "engines": {
        "node": ">= 0.4"
      }
    },
    "node_modules/escalade": {
      "version": "3.2.0",
      "resolved": "https://registry.npmjs.org/escalade/-/escalade-3.2.0.tgz",
      "integrity": "sha512-WUj2qlxaQtO4g6Pq5c29GTcWGDyd8itL8zTlipgECz3JesAiiOKotd8JU6otB3PACgG6xkJUyVhboMS+bje/jA==",
      "license": "MIT",
      "optional": true,
      "engines": {
        "node": ">=6"
      }
    },
    "node_modules/escape-html": {
      "version": "1.0.3",
      "resolved": "https://registry.npmjs.org/escape-html/-/escape-html-1.0.3.tgz",
      "integrity": "sha512-NiSupZ4OeuGwr68lGIeym/ksIZMJodUGOSCZ/FSnTxcrekbvqrgdUxlJOMpijaKZVjAJrWrGs/6Jy8OMuyj9ow==",
      "license": "MIT"
    },
    "node_modules/etag": {
      "version": "1.8.1",
      "resolved": "https://registry.npmjs.org/etag/-/etag-1.8.1.tgz",
      "integrity": "sha512-aIL5Fx7mawVa300al2BnEE4iNvo1qETxLrPI/o05L7z6go7fCw1J6EQmbK4FmJ2AS7kgVF/KEZWufBfdClMcPg==",
      "license": "MIT",
      "engines": {
        "node": ">= 0.6"
      }
    },
    "node_modules/event-target-shim": {
      "version": "5.0.1",
      "resolved": "https://registry.npmjs.org/event-target-shim/-/event-target-shim-5.0.1.tgz",
      "integrity": "sha512-i/2XbnSz/uxRCU6+NdVJgKWDTM427+MqYbkQzD321DuCQJUqOuJKIA0IM2+W2xtYHdKOmZ4dR6fExsd4SXL+WQ==",
      "license": "MIT",
      "optional": true,
      "engines": {
        "node": ">=6"
      }
    },
    "node_modules/express": {
      "version": "4.22.1",
      "resolved": "https://registry.npmjs.org/express/-/express-4.22.1.tgz",
      "integrity": "sha512-F2X8g9P1X7uCPZMA3MVf9wcTqlyNp7IhH5qPCI0izhaOIYXaW9L535tGA3qmjRzpH+bZczqq7hVKxTR4NWnu+g==",
      "license": "MIT",
      "dependencies": {
        "accepts": "~1.3.8",
        "array-flatten": "1.1.1",
        "body-parser": "~1.20.3",
        "content-disposition": "~0.5.4",
        "content-type": "~1.0.4",
        "cookie": "~0.7.1",
        "cookie-signature": "~1.0.6",
        "debug": "2.6.9",
        "depd": "2.0.0",
        "encodeurl": "~2.0.0",
        "escape-html": "~1.0.3",
        "etag": "~1.8.1",
        "finalhandler": "~1.3.1",
        "fresh": "~0.5.2",
        "http-errors": "~2.0.0",
        "merge-descriptors": "1.0.3",
        "methods": "~1.1.2",
        "on-finished": "~2.4.1",
        "parseurl": "~1.3.3",
        "path-to-regexp": "~0.1.12",
        "proxy-addr": "~2.0.7",
        "qs": "~6.14.0",
        "range-parser": "~1.2.1",
        "safe-buffer": "5.2.1",
        "send": "~0.19.0",
        "serve-static": "~1.16.2",
        "setprototypeof": "1.2.0",
        "statuses": "~2.0.1",
        "type-is": "~1.6.18",
        "utils-merge": "1.0.1",
        "vary": "~1.1.2"
      },
      "engines": {
        "node": ">= 0.10.0"
      },
      "funding": {
        "type": "opencollective",
        "url": "https://opencollective.com/express"
      }
    },
    "node_modules/extend": {
      "version": "3.0.2",
      "resolved": "https://registry.npmjs.org/extend/-/extend-3.0.2.tgz",
      "integrity": "sha512-fjquC59cD7CyW6urNXK0FBufkZcoiGG80wTuPujX590cB5Ttln20E2UB4S/WARVqhXffZl2LNgS+gQdPIIim/g==",
      "license": "MIT",
      "optional": true
    },
    "node_modules/farmhash-modern": {
      "version": "1.1.0",
      "resolved": "https://registry.npmjs.org/farmhash-modern/-/farmhash-modern-1.1.0.tgz",
      "integrity": "sha512-6ypT4XfgqJk/F3Yuv4SX26I3doUjt0GTG4a+JgWxXQpxXzTBq8fPUeGHfcYMMDPHJHm3yPOSjaeBwBGAHWXCdA==",
      "license": "MIT",
      "engines": {
        "node": ">=18.0.0"
      }
    },
    "node_modules/fast-deep-equal": {
      "version": "3.1.3",
      "resolved": "https://registry.npmjs.org/fast-deep-equal/-/fast-deep-equal-3.1.3.tgz",
      "integrity": "sha512-f3qQ9oQy9j2AhBe/H9VC91wLmKBCCU/gDOnKNAYG5hswO7BLKj09Hc5HYNz9cGI++xlpDCIgDaitVs03ATR84Q==",
      "license": "MIT",
      "optional": true
    },
    "node_modules/fast-xml-parser": {
      "version": "5.3.5",
      "resolved": "https://registry.npmjs.org/fast-xml-parser/-/fast-xml-parser-5.3.5.tgz",
      "integrity": "sha512-JeaA2Vm9ffQKp9VjvfzObuMCjUYAp5WDYhRYL5LrBPY/jUDlUtOvDfot0vKSkB9tuX885BDHjtw4fZadD95wnA==",
      "funding": [
        {
          "type": "github",
          "url": "https://github.com/sponsors/NaturalIntelligence"
        }
      ],
      "license": "MIT",
      "optional": true,
      "dependencies": {
        "strnum": "^2.1.2"
      },
      "bin": {
        "fxparser": "src/cli/cli.js"
      }
    },
    "node_modules/faye-websocket": {
      "version": "0.11.4",
      "resolved": "https://registry.npmjs.org/faye-websocket/-/faye-websocket-0.11.4.tgz",
      "integrity": "sha512-CzbClwlXAuiRQAlUyfqPgvPoNKTckTPGfwZV4ZdAhVcP2lh9KUxJg2b5GkE7XbjKQ3YJnQ9z6D9ntLAlB+tP8g==",
      "license": "Apache-2.0",
      "dependencies": {
        "websocket-driver": ">=0.5.1"
      },
      "engines": {
        "node": ">=0.8.0"
      }
    },
    "node_modules/finalhandler": {
      "version": "1.3.2",
      "resolved": "https://registry.npmjs.org/finalhandler/-/finalhandler-1.3.2.tgz",
      "integrity": "sha512-aA4RyPcd3badbdABGDuTXCMTtOneUCAYH/gxoYRTZlIJdF0YPWuGqiAsIrhNnnqdXGswYk6dGujem4w80UJFhg==",
      "license": "MIT",
      "dependencies": {
        "debug": "2.6.9",
        "encodeurl": "~2.0.0",
        "escape-html": "~1.0.3",
        "on-finished": "~2.4.1",
        "parseurl": "~1.3.3",
        "statuses": "~2.0.2",
        "unpipe": "~1.0.0"
      },
      "engines": {
        "node": ">= 0.8"
      }
    },
    "node_modules/firebase-admin": {
      "version": "12.7.0",
      "resolved": "https://registry.npmjs.org/firebase-admin/-/firebase-admin-12.7.0.tgz",
      "integrity": "sha512-raFIrOyTqREbyXsNkSHyciQLfv8AUZazehPaQS1lZBSCDYW74FYXU0nQZa3qHI4K+hawohlDbywZ4+qce9YNxA==",
      "license": "Apache-2.0",
      "dependencies": {
        "@fastify/busboy": "^3.0.0",
        "@firebase/database-compat": "1.0.8",
        "@firebase/database-types": "1.0.5",
        "@types/node": "^22.0.1",
        "farmhash-modern": "^1.1.0",
        "jsonwebtoken": "^9.0.0",
        "jwks-rsa": "^3.1.0",
        "node-forge": "^1.3.1",
        "uuid": "^10.0.0"
      },
      "engines": {
        "node": ">=14"
      },
      "optionalDependencies": {
        "@google-cloud/firestore": "^7.7.0",
        "@google-cloud/storage": "^7.7.0"
      }
    },
    "node_modules/firebase-functions": {
      "version": "5.1.1",
      "resolved": "https://registry.npmjs.org/firebase-functions/-/firebase-functions-5.1.1.tgz",
      "integrity": "sha512-KkyKZE98Leg/C73oRyuUYox04PQeeBThdygMfeX+7t1cmKWYKa/ZieYa89U8GHgED+0mF7m7wfNZOfbURYxIKg==",
      "license": "MIT",
      "dependencies": {
        "@types/cors": "^2.8.5",
        "@types/express": "4.17.3",
        "cors": "^2.8.5",
        "express": "^4.17.1",
        "protobufjs": "^7.2.2"
      },
      "bin": {
        "firebase-functions": "lib/bin/firebase-functions.js"
      },
      "engines": {
        "node": ">=14.10.0"
      },
      "peerDependencies": {
        "firebase-admin": "^11.10.0 || ^12.0.0"
      }
    },
    "node_modules/follow-redirects": {
      "version": "1.15.11",
      "resolved": "https://registry.npmjs.org/follow-redirects/-/follow-redirects-1.15.11.tgz",
      "integrity": "sha512-deG2P0JfjrTxl50XGCDyfI97ZGVCxIpfKYmfyrQ54n5FO/0gfIES8C/Psl6kWVDolizcaaxZJnTS0QSMxvnsBQ==",
      "funding": [
        {
          "type": "individual",
          "url": "https://github.com/sponsors/RubenVerborgh"
        }
      ],
      "license": "MIT",
      "engines": {
        "node": ">=4.0"
      },
      "peerDependenciesMeta": {
        "debug": {
          "optional": true
        }
      }
    },
    "node_modules/form-data": {
      "version": "4.0.5",
      "resolved": "https://registry.npmjs.org/form-data/-/form-data-4.0.5.tgz",
      "integrity": "sha512-8RipRLol37bNs2bhoV67fiTEvdTrbMUYcFTiy3+wuuOnUog2QBHCZWXDRijWQfAkhBj2Uf5UnVaiWwA5vdd82w==",
      "license": "MIT",
      "dependencies": {
        "asynckit": "^0.4.0",
        "combined-stream": "^1.0.8",
        "es-set-tostringtag": "^2.1.0",
        "hasown": "^2.0.2",
        "mime-types": "^2.1.12"
      },
      "engines": {
        "node": ">= 6"
      }
    },
    "node_modules/forwarded": {
      "version": "0.2.0",
      "resolved": "https://registry.npmjs.org/forwarded/-/forwarded-0.2.0.tgz",
      "integrity": "sha512-buRG0fpBtRHSTCOASe6hD258tEubFoRLb4ZNA6NxMVHNw2gOcwHo9wyablzMzOA5z9xA9L1KNjk/Nt6MT9aYow==",
      "license": "MIT",
      "engines": {
        "node": ">= 0.6"
      }
    },
    "node_modules/fresh": {
      "version": "0.5.2",
      "resolved": "https://registry.npmjs.org/fresh/-/fresh-0.5.2.tgz",
      "integrity": "sha512-zJ2mQYM18rEFOudeV4GShTGIQ7RbzA7ozbU9I/XBpm7kqgMywgmylMwXHxZJmkVoYkna9d2pVXVXPdYTP9ej8Q==",
      "license": "MIT",
      "engines": {
        "node": ">= 0.6"
      }
    },
    "node_modules/function-bind": {
      "version": "1.1.2",
      "resolved": "https://registry.npmjs.org/function-bind/-/function-bind-1.1.2.tgz",
      "integrity": "sha512-7XHNxH7qX9xG5mIwxkhumTox/MIRNcOgDrxWsMt2pAr23WHp6MrRlN7FBSFpCpr+oVO0F744iUgR82nJMfG2SA==",
      "license": "MIT",
      "funding": {
        "url": "https://github.com/sponsors/ljharb"
      }
    },
    "node_modules/functional-red-black-tree": {
      "version": "1.0.1",
      "resolved": "https://registry.npmjs.org/functional-red-black-tree/-/functional-red-black-tree-1.0.1.tgz",
      "integrity": "sha512-dsKNQNdj6xA3T+QlADDA7mOSlX0qiMINjn0cgr+eGHGsbSHzTabcIogz2+p/iqP1Xs6EP/sS2SbqH+brGTbq0g==",
      "license": "MIT",
      "optional": true
    },
    "node_modules/gaxios": {
      "version": "6.7.1",
      "resolved": "https://registry.npmjs.org/gaxios/-/gaxios-6.7.1.tgz",
      "integrity": "sha512-LDODD4TMYx7XXdpwxAVRAIAuB0bzv0s+ywFonY46k126qzQHT9ygyoa9tncmOiQmmDrik65UYsEkv3lbfqQ3yQ==",
      "license": "Apache-2.0",
      "optional": true,
      "dependencies": {
        "extend": "^3.0.2",
        "https-proxy-agent": "^7.0.1",
        "is-stream": "^2.0.0",
        "node-fetch": "^2.6.9",
        "uuid": "^9.0.1"
      },
      "engines": {
        "node": ">=14"
      }
    },
    "node_modules/gaxios/node_modules/uuid": {
      "version": "9.0.1",
      "resolved": "https://registry.npmjs.org/uuid/-/uuid-9.0.1.tgz",
      "integrity": "sha512-b+1eJOlsR9K8HJpow9Ok3fiWOWSIcIzXodvv0rQjVoOVNpWMpxf1wZNpt4y9h10odCNrqnYp1OBzRktckBe3sA==",
      "funding": [
        "https://github.com/sponsors/broofa",
        "https://github.com/sponsors/ctavan"
      ],
      "license": "MIT",
      "optional": true,
      "bin": {
        "uuid": "dist/bin/uuid"
      }
    },
    "node_modules/gcp-metadata": {
      "version": "6.1.1",
      "resolved": "https://registry.npmjs.org/gcp-metadata/-/gcp-metadata-6.1.1.tgz",
      "integrity": "sha512-a4tiq7E0/5fTjxPAaH4jpjkSv/uCaU2p5KC6HVGrvl0cDjA8iBZv4vv1gyzlmK0ZUKqwpOyQMKzZQe3lTit77A==",
      "license": "Apache-2.0",
      "optional": true,
      "dependencies": {
        "gaxios": "^6.1.1",
        "google-logging-utils": "^0.0.2",
        "json-bigint": "^1.0.0"
      },
      "engines": {
        "node": ">=14"
      }
    },
    "node_modules/get-caller-file": {
      "version": "2.0.5",
      "resolved": "https://registry.npmjs.org/get-caller-file/-/get-caller-file-2.0.5.tgz",
      "integrity": "sha512-DyFP3BM/3YHTQOCUL/w0OZHR0lpKeGrxotcHWcqNEdnltqFwXVfhEBQ94eIo34AfQpo0rGki4cyIiftY06h2Fg==",
      "license": "ISC",
      "optional": true,
      "engines": {
        "node": "6.* || 8.* || >= 10.*"
      }
    },
    "node_modules/get-intrinsic": {
      "version": "1.3.0",
      "resolved": "https://registry.npmjs.org/get-intrinsic/-/get-intrinsic-1.3.0.tgz",
      "integrity": "sha512-9fSjSaos/fRIVIp+xSJlE6lfwhES7LNtKaCBIamHsjr2na1BiABJPo0mOjjz8GJDURarmCPGqaiVg5mfjb98CQ==",
      "license": "MIT",
      "dependencies": {
        "call-bind-apply-helpers": "^1.0.2",
        "es-define-property": "^1.0.1",
        "es-errors": "^1.3.0",
        "es-object-atoms": "^1.1.1",
        "function-bind": "^1.1.2",
        "get-proto": "^1.0.1",
        "gopd": "^1.2.0",
        "has-symbols": "^1.1.0",
        "hasown": "^2.0.2",
        "math-intrinsics": "^1.1.0"
      },
      "engines": {
        "node": ">= 0.4"
      },
      "funding": {
        "url": "https://github.com/sponsors/ljharb"
      }
    },
    "node_modules/get-proto": {
      "version": "1.0.1",
      "resolved": "https://registry.npmjs.org/get-proto/-/get-proto-1.0.1.tgz",
      "integrity": "sha512-sTSfBjoXBp89JvIKIefqw7U2CCebsc74kiY6awiGogKtoSGbgjYE/G/+l9sF3MWFPNc9IcoOC4ODfKHfxFmp0g==",
      "license": "MIT",
      "dependencies": {
        "dunder-proto": "^1.0.1",
        "es-object-atoms": "^1.0.0"
      },
      "engines": {
        "node": ">= 0.4"
      }
    },
    "node_modules/google-auth-library": {
      "version": "9.15.1",
      "resolved": "https://registry.npmjs.org/google-auth-library/-/google-auth-library-9.15.1.tgz",
      "integrity": "sha512-Jb6Z0+nvECVz+2lzSMt9u98UsoakXxA2HGHMCxh+so3n90XgYWkq5dur19JAJV7ONiJY22yBTyJB1TSkvPq9Ng==",
      "license": "Apache-2.0",
      "optional": true,
      "dependencies": {
        "base64-js": "^1.3.0",
        "ecdsa-sig-formatter": "^1.0.11",
        "gaxios": "^6.1.1",
        "gcp-metadata": "^6.1.0",
        "gtoken": "^7.0.0",
        "jws": "^4.0.0"
      },
      "engines": {
        "node": ">=14"
      }
    },
    "node_modules/google-gax": {
      "version": "4.6.1",
      "resolved": "https://registry.npmjs.org/google-gax/-/google-gax-4.6.1.tgz",
      "integrity": "sha512-V6eky/xz2mcKfAd1Ioxyd6nmA61gao3n01C+YeuIwu3vzM9EDR6wcVzMSIbLMDXWeoi9SHYctXuKYC5uJUT3eQ==",
      "license": "Apache-2.0",
      "optional": true,
      "dependencies": {
        "@grpc/grpc-js": "^1.10.9",
        "@grpc/proto-loader": "^0.7.13",
        "@types/long": "^4.0.0",
        "abort-controller": "^3.0.0",
        "duplexify": "^4.0.0",
        "google-auth-library": "^9.3.0",
        "node-fetch": "^2.7.0",
        "object-hash": "^3.0.0",
        "proto3-json-serializer": "^2.0.2",
        "protobufjs": "^7.3.2",
        "retry-request": "^7.0.0",
        "uuid": "^9.0.1"
      },
      "engines": {
        "node": ">=14"
      }
    },
    "node_modules/google-gax/node_modules/uuid": {
      "version": "9.0.1",
      "resolved": "https://registry.npmjs.org/uuid/-/uuid-9.0.1.tgz",
      "integrity": "sha512-b+1eJOlsR9K8HJpow9Ok3fiWOWSIcIzXodvv0rQjVoOVNpWMpxf1wZNpt4y9h10odCNrqnYp1OBzRktckBe3sA==",
      "funding": [
        "https://github.com/sponsors/broofa",
        "https://github.com/sponsors/ctavan"
      ],
      "license": "MIT",
      "optional": true,
      "bin": {
        "uuid": "dist/bin/uuid"
      }
    },
    "node_modules/google-logging-utils": {
      "version": "0.0.2",
      "resolved": "https://registry.npmjs.org/google-logging-utils/-/google-logging-utils-0.0.2.tgz",
      "integrity": "sha512-NEgUnEcBiP5HrPzufUkBzJOD/Sxsco3rLNo1F1TNf7ieU8ryUzBhqba8r756CjLX7rn3fHl6iLEwPYuqpoKgQQ==",
      "license": "Apache-2.0",
      "optional": true,
      "engines": {
        "node": ">=14"
      }
    },
    "node_modules/gopd": {
      "version": "1.2.0",
      "resolved": "https://registry.npmjs.org/gopd/-/gopd-1.2.0.tgz",
      "integrity": "sha512-ZUKRh6/kUFoAiTAtTYPZJ3hw9wNxx+BIBOijnlG9PnrJsCcSjs1wyyD6vJpaYtgnzDrKYRSqf3OO6Rfa93xsRg==",
      "license": "MIT",
      "engines": {
        "node": ">= 0.4"
      },
      "funding": {
        "url": "https://github.com/sponsors/ljharb"
      }
    },
    "node_modules/gtoken": {
      "version": "7.1.0",
      "resolved": "https://registry.npmjs.org/gtoken/-/gtoken-7.1.0.tgz",
      "integrity": "sha512-pCcEwRi+TKpMlxAQObHDQ56KawURgyAf6jtIY046fJ5tIv3zDe/LEIubckAO8fj6JnAxLdmWkUfNyulQ2iKdEw==",
      "license": "MIT",
      "optional": true,
      "dependencies": {
        "gaxios": "^6.0.0",
        "jws": "^4.0.0"
      },
      "engines": {
        "node": ">=14.0.0"
      }
    },
    "node_modules/has-symbols": {
      "version": "1.1.0",
      "resolved": "https://registry.npmjs.org/has-symbols/-/has-symbols-1.1.0.tgz",
      "integrity": "sha512-1cDNdwJ2Jaohmb3sg4OmKaMBwuC48sYni5HUw2DvsC8LjGTLK9h+eb1X6RyuOHe4hT0ULCW68iomhjUoKUqlPQ==",
      "license": "MIT",
      "engines": {
        "node": ">= 0.4"
      },
      "funding": {
        "url": "https://github.com/sponsors/ljharb"
      }
    },
    "node_modules/has-tostringtag": {
      "version": "1.0.2",
      "resolved": "https://registry.npmjs.org/has-tostringtag/-/has-tostringtag-1.0.2.tgz",
      "integrity": "sha512-NqADB8VjPFLM2V0VvHUewwwsw0ZWBaIdgo+ieHtK3hasLz4qeCRjYcqfB6AQrBggRKppKF8L52/VqdVsO47Dlw==",
      "license": "MIT",
      "dependencies": {
        "has-symbols": "^1.0.3"
      },
      "engines": {
        "node": ">= 0.4"
      },
      "funding": {
        "url": "https://github.com/sponsors/ljharb"
      }
    },
    "node_modules/hasown": {
      "version": "2.0.2",
      "resolved": "https://registry.npmjs.org/hasown/-/hasown-2.0.2.tgz",
      "integrity": "sha512-0hJU9SCPvmMzIBdZFqNPXWa6dqh7WdH0cII9y+CyS8rG3nL48Bclra9HmKhVVUHyPWNH5Y7xDwAB7bfgSjkUMQ==",
      "license": "MIT",
      "dependencies": {
        "function-bind": "^1.1.2"
      },
      "engines": {
        "node": ">= 0.4"
      }
    },
    "node_modules/html-entities": {
      "version": "2.6.0",
      "resolved": "https://registry.npmjs.org/html-entities/-/html-entities-2.6.0.tgz",
      "integrity": "sha512-kig+rMn/QOVRvr7c86gQ8lWXq+Hkv6CbAH1hLu+RG338StTpE8Z0b44SDVaqVu7HGKf27frdmUYEs9hTUX/cLQ==",
      "funding": [
        {
          "type": "github",
          "url": "https://github.com/sponsors/mdevils"
        },
        {
          "type": "patreon",
          "url": "https://patreon.com/mdevils"
        }
      ],
      "license": "MIT",
      "optional": true
    },
    "node_modules/http-errors": {
      "version": "2.0.1",
      "resolved": "https://registry.npmjs.org/http-errors/-/http-errors-2.0.1.tgz",
      "integrity": "sha512-4FbRdAX+bSdmo4AUFuS0WNiPz8NgFt+r8ThgNWmlrjQjt1Q7ZR9+zTlce2859x4KSXrwIsaeTqDoKQmtP8pLmQ==",
      "license": "MIT",
      "dependencies": {
        "depd": "~2.0.0",
        "inherits": "~2.0.4",
        "setprototypeof": "~1.2.0",
        "statuses": "~2.0.2",
        "toidentifier": "~1.0.1"
      },
      "engines": {
        "node": ">= 0.8"
      },
      "funding": {
        "type": "opencollective",
        "url": "https://opencollective.com/express"
      }
    },
    "node_modules/http-parser-js": {
      "version": "0.5.10",
      "resolved": "https://registry.npmjs.org/http-parser-js/-/http-parser-js-0.5.10.tgz",
      "integrity": "sha512-Pysuw9XpUq5dVc/2SMHpuTY01RFl8fttgcyunjL7eEMhGM3cI4eOmiCycJDVCo/7O7ClfQD3SaI6ftDzqOXYMA==",
      "license": "MIT"
    },
    "node_modules/http-proxy-agent": {
      "version": "5.0.0",
      "resolved": "https://registry.npmjs.org/http-proxy-agent/-/http-proxy-agent-5.0.0.tgz",
      "integrity": "sha512-n2hY8YdoRE1i7r6M0w9DIw5GgZN0G25P8zLCRQ8rjXtTU3vsNFBI/vWK/UIeE6g5MUUz6avwAPXmL6Fy9D/90w==",
      "license": "MIT",
      "optional": true,
      "dependencies": {
        "@tootallnate/once": "2",
        "agent-base": "6",
        "debug": "4"
      },
      "engines": {
        "node": ">= 6"
      }
    },
    "node_modules/http-proxy-agent/node_modules/agent-base": {
      "version": "6.0.2",
      "resolved": "https://registry.npmjs.org/agent-base/-/agent-base-6.0.2.tgz",
      "integrity": "sha512-RZNwNclF7+MS/8bDg70amg32dyeZGZxiDuQmZxKLAlQjr3jGyLx+4Kkk58UO7D2QdgFIQCovuSuZESne6RG6XQ==",
      "license": "MIT",
      "optional": true,
      "dependencies": {
        "debug": "4"
      },
      "engines": {
        "node": ">= 6.0.0"
      }
    },
    "node_modules/http-proxy-agent/node_modules/debug": {
      "version": "4.4.3",
      "resolved": "https://registry.npmjs.org/debug/-/debug-4.4.3.tgz",
      "integrity": "sha512-RGwwWnwQvkVfavKVt22FGLw+xYSdzARwm0ru6DhTVA3umU5hZc28V3kO4stgYryrTlLpuvgI9GiijltAjNbcqA==",
      "license": "MIT",
      "optional": true,
      "dependencies": {
        "ms": "^2.1.3"
      },
      "engines": {
        "node": ">=6.0"
      },
      "peerDependenciesMeta": {
        "supports-color": {
          "optional": true
        }
      }
    },
    "node_modules/http-proxy-agent/node_modules/ms": {
      "version": "2.1.3",
      "resolved": "https://registry.npmjs.org/ms/-/ms-2.1.3.tgz",
      "integrity": "sha512-6FlzubTLZG3J2a/NVCAleEhjzq5oxgHyaCU9yYXvcLsvoVaHJq/s5xXI6/XXP6tz7R9xAOtHnSO/tXtF3WRTlA==",
      "license": "MIT",
      "optional": true
    },
    "node_modules/https-proxy-agent": {
      "version": "7.0.6",
      "resolved": "https://registry.npmjs.org/https-proxy-agent/-/https-proxy-agent-7.0.6.tgz",
      "integrity": "sha512-vK9P5/iUfdl95AI+JVyUuIcVtd4ofvtrOr3HNtM2yxC9bnMbEdp3x01OhQNnjb8IJYi38VlTE3mBXwcfvywuSw==",
      "license": "MIT",
      "optional": true,
      "dependencies": {
        "agent-base": "^7.1.2",
        "debug": "4"
      },
      "engines": {
        "node": ">= 14"
      }
    },
    "node_modules/https-proxy-agent/node_modules/debug": {
      "version": "4.4.3",
      "resolved": "https://registry.npmjs.org/debug/-/debug-4.4.3.tgz",
      "integrity": "sha512-RGwwWnwQvkVfavKVt22FGLw+xYSdzARwm0ru6DhTVA3umU5hZc28V3kO4stgYryrTlLpuvgI9GiijltAjNbcqA==",
      "license": "MIT",
      "optional": true,
      "dependencies": {
        "ms": "^2.1.3"
      },
      "engines": {
        "node": ">=6.0"
      },
      "peerDependenciesMeta": {
        "supports-color": {
          "optional": true
        }
      }
    },
    "node_modules/https-proxy-agent/node_modules/ms": {
      "version": "2.1.3",
      "resolved": "https://registry.npmjs.org/ms/-/ms-2.1.3.tgz",
      "integrity": "sha512-6FlzubTLZG3J2a/NVCAleEhjzq5oxgHyaCU9yYXvcLsvoVaHJq/s5xXI6/XXP6tz7R9xAOtHnSO/tXtF3WRTlA==",
      "license": "MIT",
      "optional": true
    },
    "node_modules/iconv-lite": {
      "version": "0.4.24",
      "resolved": "https://registry.npmjs.org/iconv-lite/-/iconv-lite-0.4.24.tgz",
      "integrity": "sha512-v3MXnZAcvnywkTUEZomIActle7RXXeedOR31wwl7VlyoXO4Qi9arvSenNQWne1TcRwhCL1HwLI21bEqdpj8/rA==",
      "license": "MIT",
      "dependencies": {
        "safer-buffer": ">= 2.1.2 < 3"
      },
      "engines": {
        "node": ">=0.10.0"
      }
    },
    "node_modules/inherits": {
      "version": "2.0.4",
      "resolved": "https://registry.npmjs.org/inherits/-/inherits-2.0.4.tgz",
      "integrity": "sha512-k/vGaX4/Yla3WzyMCvTQOXYeIHvqOKtnqBduzTHpzpQZzAskKMhZ2K+EnBiSM9zGSoIFeMpXKxa4dYeZIQqewQ==",
      "license": "ISC"
    },
    "node_modules/ipaddr.js": {
      "version": "1.9.1",
      "resolved": "https://registry.npmjs.org/ipaddr.js/-/ipaddr.js-1.9.1.tgz",
      "integrity": "sha512-0KI/607xoxSToH7GjN1FfSbLoU0+btTicjsQSWQlh/hZykN8KpmMf7uYwPW3R+akZ6R/w18ZlXSHBYXiYUPO3g==",
      "license": "MIT",
      "engines": {
        "node": ">= 0.10"
      }
    },
    "node_modules/is-fullwidth-code-point": {
      "version": "3.0.0",
      "resolved": "https://registry.npmjs.org/is-fullwidth-code-point/-/is-fullwidth-code-point-3.0.0.tgz",
      "integrity": "sha512-zymm5+u+sCsSWyD9qNaejV3DFvhCKclKdizYaJUuHA83RLjb7nSuGnddCHGv0hk+KY7BMAlsWeK4Ueg6EV6XQg==",
      "license": "MIT",
      "optional": true,
      "engines": {
        "node": ">=8"
      }
    },
    "node_modules/is-stream": {
      "version": "2.0.1",
      "resolved": "https://registry.npmjs.org/is-stream/-/is-stream-2.0.1.tgz",
      "integrity": "sha512-hFoiJiTl63nn+kstHGBtewWSKnQLpyb155KHheA1l39uvtO9nWIop1p3udqPcUd/xbF1VLMO4n7OI6p7RbngDg==",
      "license": "MIT",
      "optional": true,
      "engines": {
        "node": ">=8"
      },
      "funding": {
        "url": "https://github.com/sponsors/sindresorhus"
      }
    },
    "node_modules/jose": {
      "version": "4.15.9",
      "resolved": "https://registry.npmjs.org/jose/-/jose-4.15.9.tgz",
      "integrity": "sha512-1vUQX+IdDMVPj4k8kOxgUqlcK518yluMuGZwqlr44FS1ppZB/5GWh4rZG89erpOBOJjU/OBsnCVFfapsRz6nEA==",
      "license": "MIT",
      "funding": {
        "url": "https://github.com/sponsors/panva"
      }
    },
    "node_modules/json-bigint": {
      "version": "1.0.0",
      "resolved": "https://registry.npmjs.org/json-bigint/-/json-bigint-1.0.0.tgz",
      "integrity": "sha512-SiPv/8VpZuWbvLSMtTDU8hEfrZWg/mH/nV/b4o0CYbSxu1UIQPLdwKOCIyLQX+VIPO5vrLX3i8qtqFyhdPSUSQ==",
      "license": "MIT",
      "optional": true,
      "dependencies": {
        "bignumber.js": "^9.0.0"
      }
    },
    "node_modules/jsonwebtoken": {
      "version": "9.0.3",
      "resolved": "https://registry.npmjs.org/jsonwebtoken/-/jsonwebtoken-9.0.3.tgz",
      "integrity": "sha512-MT/xP0CrubFRNLNKvxJ2BYfy53Zkm++5bX9dtuPbqAeQpTVe0MQTFhao8+Cp//EmJp244xt6Drw/GVEGCUj40g==",
      "license": "MIT",
      "dependencies": {
        "jws": "^4.0.1",
        "lodash.includes": "^4.3.0",
        "lodash.isboolean": "^3.0.3",
        "lodash.isinteger": "^4.0.4",
        "lodash.isnumber": "^3.0.3",
        "lodash.isplainobject": "^4.0.6",
        "lodash.isstring": "^4.0.1",
        "lodash.once": "^4.0.0",
        "ms": "^2.1.1",
        "semver": "^7.5.4"
      },
      "engines": {
        "node": ">=12",
        "npm": ">=6"
      }
    },
    "node_modules/jsonwebtoken/node_modules/ms": {
      "version": "2.1.3",
      "resolved": "https://registry.npmjs.org/ms/-/ms-2.1.3.tgz",
      "integrity": "sha512-6FlzubTLZG3J2a/NVCAleEhjzq5oxgHyaCU9yYXvcLsvoVaHJq/s5xXI6/XXP6tz7R9xAOtHnSO/tXtF3WRTlA==",
      "license": "MIT"
    },
    "node_modules/jwa": {
      "version": "2.0.1",
      "resolved": "https://registry.npmjs.org/jwa/-/jwa-2.0.1.tgz",
      "integrity": "sha512-hRF04fqJIP8Abbkq5NKGN0Bbr3JxlQ+qhZufXVr0DvujKy93ZCbXZMHDL4EOtodSbCWxOqR8MS1tXA5hwqCXDg==",
      "license": "MIT",
      "dependencies": {
        "buffer-equal-constant-time": "^1.0.1",
        "ecdsa-sig-formatter": "1.0.11",
        "safe-buffer": "^5.0.1"
      }
    },
    "node_modules/jwks-rsa": {
      "version": "3.2.2",
      "resolved": "https://registry.npmjs.org/jwks-rsa/-/jwks-rsa-3.2.2.tgz",
      "integrity": "sha512-BqTyEDV+lS8F2trk3A+qJnxV5Q9EqKCBJOPti3W97r7qTympCZjb7h2X6f2kc+0K3rsSTY1/6YG2eaXKoj497w==",
      "license": "MIT",
      "dependencies": {
        "@types/jsonwebtoken": "^9.0.4",
        "debug": "^4.3.4",
        "jose": "^4.15.4",
        "limiter": "^1.1.5",
        "lru-memoizer": "^2.2.0"
      },
      "engines": {
        "node": ">=14"
      }
    },
    "node_modules/jwks-rsa/node_modules/debug": {
      "version": "4.4.3",
      "resolved": "https://registry.npmjs.org/debug/-/debug-4.4.3.tgz",
      "integrity": "sha512-RGwwWnwQvkVfavKVt22FGLw+xYSdzARwm0ru6DhTVA3umU5hZc28V3kO4stgYryrTlLpuvgI9GiijltAjNbcqA==",
      "license": "MIT",
      "dependencies": {
        "ms": "^2.1.3"
      },
      "engines": {
        "node": ">=6.0"
      },
      "peerDependenciesMeta": {
        "supports-color": {
          "optional": true
        }
      }
    },
    "node_modules/jwks-rsa/node_modules/ms": {
      "version": "2.1.3",
      "resolved": "https://registry.npmjs.org/ms/-/ms-2.1.3.tgz",
      "integrity": "sha512-6FlzubTLZG3J2a/NVCAleEhjzq5oxgHyaCU9yYXvcLsvoVaHJq/s5xXI6/XXP6tz7R9xAOtHnSO/tXtF3WRTlA==",
      "license": "MIT"
    },
    "node_modules/jws": {
      "version": "4.0.1",
      "resolved": "https://registry.npmjs.org/jws/-/jws-4.0.1.tgz",
      "integrity": "sha512-EKI/M/yqPncGUUh44xz0PxSidXFr/+r0pA70+gIYhjv+et7yxM+s29Y+VGDkovRofQem0fs7Uvf4+YmAdyRduA==",
      "license": "MIT",
      "dependencies": {
        "jwa": "^2.0.1",
        "safe-buffer": "^5.0.1"
      }
    },
    "node_modules/limiter": {
      "version": "1.1.5",
      "resolved": "https://registry.npmjs.org/limiter/-/limiter-1.1.5.tgz",
      "integrity": "sha512-FWWMIEOxz3GwUI4Ts/IvgVy6LPvoMPgjMdQ185nN6psJyBJ4yOpzqm695/h5umdLJg2vW3GR5iG11MAkR2AzJA=="
    },
    "node_modules/lodash.camelcase": {
      "version": "4.3.0",
      "resolved": "https://registry.npmjs.org/lodash.camelcase/-/lodash.camelcase-4.3.0.tgz",
      "integrity": "sha512-TwuEnCnxbc3rAvhf/LbG7tJUDzhqXyFnv3dtzLOPgCG/hODL7WFnsbwktkD7yUV0RrreP/l1PALq/YSg6VvjlA==",
      "license": "MIT",
      "optional": true
    },
    "node_modules/lodash.clonedeep": {
      "version": "4.5.0",
      "resolved": "https://registry.npmjs.org/lodash.clonedeep/-/lodash.clonedeep-4.5.0.tgz",
      "integrity": "sha512-H5ZhCF25riFd9uB5UCkVKo61m3S/xZk1x4wA6yp/L3RFP6Z/eHH1ymQcGLo7J3GMPfm0V/7m1tryHuGVxpqEBQ==",
      "license": "MIT"
    },
    "node_modules/lodash.includes": {
      "version": "4.3.0",
      "resolved": "https://registry.npmjs.org/lodash.includes/-/lodash.includes-4.3.0.tgz",
      "integrity": "sha512-W3Bx6mdkRTGtlJISOvVD/lbqjTlPPUDTMnlXZFnVwi9NKJ6tiAk6LVdlhZMm17VZisqhKcgzpO5Wz91PCt5b0w==",
      "license": "MIT"
    },
    "node_modules/lodash.isboolean": {
      "version": "3.0.3",
      "resolved": "https://registry.npmjs.org/lodash.isboolean/-/lodash.isboolean-3.0.3.tgz",
      "integrity": "sha512-Bz5mupy2SVbPHURB98VAcw+aHh4vRV5IPNhILUCsOzRmsTmSQ17jIuqopAentWoehktxGd9e/hbIXq980/1QJg==",
      "license": "MIT"
    },
    "node_modules/lodash.isinteger": {
      "version": "4.0.4",
      "resolved": "https://registry.npmjs.org/lodash.isinteger/-/lodash.isinteger-4.0.4.tgz",
      "integrity": "sha512-DBwtEWN2caHQ9/imiNeEA5ys1JoRtRfY3d7V9wkqtbycnAmTvRRmbHKDV4a0EYc678/dia0jrte4tjYwVBaZUA==",
      "license": "MIT"
    },
    "node_modules/lodash.isnumber": {
      "version": "3.0.3",
      "resolved": "https://registry.npmjs.org/lodash.isnumber/-/lodash.isnumber-3.0.3.tgz",
      "integrity": "sha512-QYqzpfwO3/CWf3XP+Z+tkQsfaLL/EnUlXWVkIk5FUPc4sBdTehEqZONuyRt2P67PXAk+NXmTBcc97zw9t1FQrw==",
      "license": "MIT"
    },
    "node_modules/lodash.isplainobject": {
      "version": "4.0.6",
      "resolved": "https://registry.npmjs.org/lodash.isplainobject/-/lodash.isplainobject-4.0.6.tgz",
      "integrity": "sha512-oSXzaWypCMHkPC3NvBEaPHf0KsA5mvPrOPgQWDsbg8n7orZ290M0BmC/jgRZ4vcJ6DTAhjrsSYgdsW/F+MFOBA==",
      "license": "MIT"
    },
    "node_modules/lodash.isstring": {
      "version": "4.0.1",
      "resolved": "https://registry.npmjs.org/lodash.isstring/-/lodash.isstring-4.0.1.tgz",
      "integrity": "sha512-0wJxfxH1wgO3GrbuP+dTTk7op+6L41QCXbGINEmD+ny/G/eCqGzxyCsh7159S+mgDDcoarnBw6PC1PS5+wUGgw==",
      "license": "MIT"
    },
    "node_modules/lodash.once": {
      "version": "4.1.1",
      "resolved": "https://registry.npmjs.org/lodash.once/-/lodash.once-4.1.1.tgz",
      "integrity": "sha512-Sb487aTOCr9drQVL8pIxOzVhafOjZN9UU54hiN8PU3uAiSV7lx1yYNpbNmex2PK6dSJoNTSJUUswT651yww3Mg==",
      "license": "MIT"
    },
    "node_modules/long": {
      "version": "5.3.2",
      "resolved": "https://registry.npmjs.org/long/-/long-5.3.2.tgz",
      "integrity": "sha512-mNAgZ1GmyNhD7AuqnTG3/VQ26o760+ZYBPKjPvugO8+nLbYfX6TVpJPseBvopbdY+qpZ/lKUnmEc1LeZYS3QAA==",
      "license": "Apache-2.0"
    },
    "node_modules/lru-cache": {
      "version": "6.0.0",
      "resolved": "https://registry.npmjs.org/lru-cache/-/lru-cache-6.0.0.tgz",
      "integrity": "sha512-Jo6dJ04CmSjuznwJSS3pUeWmd/H0ffTlkXXgwZi+eq1UCmqQwCh+eLsYOYCwY991i2Fah4h1BEMCx4qThGbsiA==",
      "license": "ISC",
      "dependencies": {
        "yallist": "^4.0.0"
      },
      "engines": {
        "node": ">=10"
      }
    },
    "node_modules/lru-memoizer": {
      "version": "2.3.0",
      "resolved": "https://registry.npmjs.org/lru-memoizer/-/lru-memoizer-2.3.0.tgz",
      "integrity": "sha512-GXn7gyHAMhO13WSKrIiNfztwxodVsP8IoZ3XfrJV4yH2x0/OeTO/FIaAHTY5YekdGgW94njfuKmyyt1E0mR6Ug==",
      "license": "MIT",
      "dependencies": {
        "lodash.clonedeep": "^4.5.0",
        "lru-cache": "6.0.0"
      }
    },
    "node_modules/math-intrinsics": {
      "version": "1.1.0",
      "resolved": "https://registry.npmjs.org/math-intrinsics/-/math-intrinsics-1.1.0.tgz",
      "integrity": "sha512-/IXtbwEk5HTPyEwyKX6hGkYXxM9nbj64B+ilVJnC/R6B0pH5G4V3b0pVbL7DBj4tkhBAppbQUlf6F6Xl9LHu1g==",
      "license": "MIT",
      "engines": {
        "node": ">= 0.4"
      }
    },
    "node_modules/media-typer": {
      "version": "0.3.0",
      "resolved": "https://registry.npmjs.org/media-typer/-/media-typer-0.3.0.tgz",
      "integrity": "sha512-dq+qelQ9akHpcOl/gUVRTxVIOkAJ1wR3QAvb4RsVjS8oVoFjDGTc679wJYmUmknUF5HwMLOgb5O+a3KxfWapPQ==",
      "license": "MIT",
      "engines": {
        "node": ">= 0.6"
      }
    },
    "node_modules/merge-descriptors": {
      "version": "1.0.3",
      "resolved": "https://registry.npmjs.org/merge-descriptors/-/merge-descriptors-1.0.3.tgz",
      "integrity": "sha512-gaNvAS7TZ897/rVaZ0nMtAyxNyi/pdbjbAwUpFQpN70GqnVfOiXpeUUMKRBmzXaSQ8DdTX4/0ms62r2K+hE6mQ==",
      "license": "MIT",
      "funding": {
        "url": "https://github.com/sponsors/sindresorhus"
      }
    },
    "node_modules/methods": {
      "version": "1.1.2",
      "resolved": "https://registry.npmjs.org/methods/-/methods-1.1.2.tgz",
      "integrity": "sha512-iclAHeNqNm68zFtnZ0e+1L2yUIdvzNoauKU4WBA3VvH/vPFieF7qfRlwUZU+DA9P9bPXIS90ulxoUoCH23sV2w==",
      "license": "MIT",
      "engines": {
        "node": ">= 0.6"
      }
    },
    "node_modules/mime": {
      "version": "3.0.0",
      "resolved": "https://registry.npmjs.org/mime/-/mime-3.0.0.tgz",
      "integrity": "sha512-jSCU7/VB1loIWBZe14aEYHU/+1UMEHoaO7qxCOVJOw9GgH72VAWppxNcjU+x9a2k3GSIBXNKxXQFqRvvZ7vr3A==",
      "license": "MIT",
      "optional": true,
      "bin": {
        "mime": "cli.js"
      },
      "engines": {
        "node": ">=10.0.0"
      }
    },
    "node_modules/mime-db": {
      "version": "1.52.0",
      "resolved": "https://registry.npmjs.org/mime-db/-/mime-db-1.52.0.tgz",
      "integrity": "sha512-sPU4uV7dYlvtWJxwwxHD0PuihVNiE7TyAbQ5SWxDCB9mUYvOgroQOwYQQOKPJ8CIbE+1ETVlOoK1UC2nU3gYvg==",
      "license": "MIT",
      "engines": {
        "node": ">= 0.6"
      }
    },
    "node_modules/mime-types": {
      "version": "2.1.35",
      "resolved": "https://registry.npmjs.org/mime-types/-/mime-types-2.1.35.tgz",
      "integrity": "sha512-ZDY+bPm5zTTF+YpCrAU9nK0UgICYPT0QtT1NZWFv4s++TNkcgVaT0g6+4R2uI4MjQjzysHB1zxuWL50hzaeXiw==",
      "license": "MIT",
      "dependencies": {
        "mime-db": "1.52.0"
      },
      "engines": {
        "node": ">= 0.6"
      }
    },
    "node_modules/ms": {
      "version": "2.0.0",
      "resolved": "https://registry.npmjs.org/ms/-/ms-2.0.0.tgz",
      "integrity": "sha512-Tpp60P6IUJDTuOq/5Z8cdskzJujfwqfOTkrwIwj7IRISpnkJnT6SyJ4PCPnGMoFjC9ddhal5KVIYtAt97ix05A==",
      "license": "MIT"
    },
    "node_modules/negotiator": {
      "version": "0.6.3",
      "resolved": "https://registry.npmjs.org/negotiator/-/negotiator-0.6.3.tgz",
      "integrity": "sha512-+EUsqGPLsM+j/zdChZjsnX51g4XrHFOIXwfnCVPGlQk/k5giakcKsuxCObBRu6DSm9opw/O6slWbJdghQM4bBg==",
      "license": "MIT",
      "engines": {
        "node": ">= 0.6"
      }
    },
    "node_modules/node-fetch": {
      "version": "2.7.0",
      "resolved": "https://registry.npmjs.org/node-fetch/-/node-fetch-2.7.0.tgz",
      "integrity": "sha512-c4FRfUm/dbcWZ7U+1Wq0AwCyFL+3nt2bEw05wfxSz+DWpWsitgmSgYmy2dQdWyKC1694ELPqMs/YzUSNozLt8A==",
      "license": "MIT",
      "optional": true,
      "dependencies": {
        "whatwg-url": "^5.0.0"
      },
      "engines": {
        "node": "4.x || >=6.0.0"
      },
      "peerDependencies": {
        "encoding": "^0.1.0"
      },
      "peerDependenciesMeta": {
        "encoding": {
          "optional": true
        }
      }
    },
    "node_modules/node-forge": {
      "version": "1.3.3",
      "resolved": "https://registry.npmjs.org/node-forge/-/node-forge-1.3.3.tgz",
      "integrity": "sha512-rLvcdSyRCyouf6jcOIPe/BgwG/d7hKjzMKOas33/pHEr6gbq18IK9zV7DiPvzsz0oBJPme6qr6H6kGZuI9/DZg==",
      "license": "(BSD-3-Clause OR GPL-2.0)",
      "engines": {
        "node": ">= 6.13.0"
      }
    },
    "node_modules/object-assign": {
      "version": "4.1.1",
      "resolved": "https://registry.npmjs.org/object-assign/-/object-assign-4.1.1.tgz",
      "integrity": "sha512-rJgTQnkUnH1sFw8yT6VSU3zD3sWmu6sZhIseY8VX+GRu3P6F7Fu+JNDoXfklElbLJSnc3FUQHVe4cU5hj+BcUg==",
      "license": "MIT",
      "engines": {
        "node": ">=0.10.0"
      }
    },
    "node_modules/object-hash": {
      "version": "3.0.0",
      "resolved": "https://registry.npmjs.org/object-hash/-/object-hash-3.0.0.tgz",
      "integrity": "sha512-RSn9F68PjH9HqtltsSnqYC1XXoWe9Bju5+213R98cNGttag9q9yAOTzdbsqvIa7aNm5WffBZFpWYr2aWrklWAw==",
      "license": "MIT",
      "optional": true,
      "engines": {
        "node": ">= 6"
      }
    },
    "node_modules/object-inspect": {
      "version": "1.13.4",
      "resolved": "https://registry.npmjs.org/object-inspect/-/object-inspect-1.13.4.tgz",
      "integrity": "sha512-W67iLl4J2EXEGTbfeHCffrjDfitvLANg0UlX3wFUUSTx92KXRFegMHUVgSqE+wvhAbi4WqjGg9czysTV2Epbew==",
      "license": "MIT",
      "engines": {
        "node": ">= 0.4"
      },
      "funding": {
        "url": "https://github.com/sponsors/ljharb"
      }
    },
    "node_modules/on-finished": {
      "version": "2.4.1",
      "resolved": "https://registry.npmjs.org/on-finished/-/on-finished-2.4.1.tgz",
      "integrity": "sha512-oVlzkg3ENAhCk2zdv7IJwd/QUD4z2RxRwpkcGY8psCVcCYZNq4wYnVWALHM+brtuJjePWiYF/ClmuDr8Ch5+kg==",
      "license": "MIT",
      "dependencies": {
        "ee-first": "1.1.1"
      },
      "engines": {
        "node": ">= 0.8"
      }
    },
    "node_modules/once": {
      "version": "1.4.0",
      "resolved": "https://registry.npmjs.org/once/-/once-1.4.0.tgz",
      "integrity": "sha512-lNaJgI+2Q5URQBkccEKHTQOPaXdUxnZZElQTZY0MFUAuaEqe1E+Nyvgdz/aIyNi6Z9MzO5dv1H8n58/GELp3+w==",
      "license": "ISC",
      "optional": true,
      "dependencies": {
        "wrappy": "1"
      }
    },
    "node_modules/p-limit": {
      "version": "3.1.0",
      "resolved": "https://registry.npmjs.org/p-limit/-/p-limit-3.1.0.tgz",
      "integrity": "sha512-TYOanM3wGwNGsZN2cVTYPArw454xnXj5qmWF1bEoAc4+cU/ol7GVh7odevjp1FNHduHc3KZMcFduxU5Xc6uJRQ==",
      "license": "MIT",
      "optional": true,
      "dependencies": {
        "yocto-queue": "^0.1.0"
      },
      "engines": {
        "node": ">=10"
      },
      "funding": {
        "url": "https://github.com/sponsors/sindresorhus"
      }
    },
    "node_modules/parseurl": {
      "version": "1.3.3",
      "resolved": "https://registry.npmjs.org/parseurl/-/parseurl-1.3.3.tgz",
      "integrity": "sha512-CiyeOxFT/JZyN5m0z9PfXw4SCBJ6Sygz1Dpl0wqjlhDEGGBP1GnsUVEL0p63hoG1fcj3fHynXi9NYO4nWOL+qQ==",
      "license": "MIT",
      "engines": {
        "node": ">= 0.8"
      }
    },
    "node_modules/path-to-regexp": {
      "version": "0.1.12",
      "resolved": "https://registry.npmjs.org/path-to-regexp/-/path-to-regexp-0.1.12.tgz",
      "integrity": "sha512-RA1GjUVMnvYFxuqovrEqZoxxW5NUZqbwKtYz/Tt7nXerk0LbLblQmrsgdeOxV5SFHf0UDggjS/bSeOZwt1pmEQ==",
      "license": "MIT"
    },
    "node_modules/proto3-json-serializer": {
      "version": "2.0.2",
      "resolved": "https://registry.npmjs.org/proto3-json-serializer/-/proto3-json-serializer-2.0.2.tgz",
      "integrity": "sha512-SAzp/O4Yh02jGdRc+uIrGoe87dkN/XtwxfZ4ZyafJHymd79ozp5VG5nyZ7ygqPM5+cpLDjjGnYFUkngonyDPOQ==",
      "license": "Apache-2.0",
      "optional": true,
      "dependencies": {
        "protobufjs": "^7.2.5"
      },
      "engines": {
        "node": ">=14.0.0"
      }
    },
    "node_modules/protobufjs": {
      "version": "7.5.4",
      "resolved": "https://registry.npmjs.org/protobufjs/-/protobufjs-7.5.4.tgz",
      "integrity": "sha512-CvexbZtbov6jW2eXAvLukXjXUW1TzFaivC46BpWc/3BpcCysb5Vffu+B3XHMm8lVEuy2Mm4XGex8hBSg1yapPg==",
      "hasInstallScript": true,
      "license": "BSD-3-Clause",
      "dependencies": {
        "@protobufjs/aspromise": "^1.1.2",
        "@protobufjs/base64": "^1.1.2",
        "@protobufjs/codegen": "^2.0.4",
        "@protobufjs/eventemitter": "^1.1.0",
        "@protobufjs/fetch": "^1.1.0",
        "@protobufjs/float": "^1.0.2",
        "@protobufjs/inquire": "^1.1.0",
        "@protobufjs/path": "^1.1.2",
        "@protobufjs/pool": "^1.1.0",
        "@protobufjs/utf8": "^1.1.0",
        "@types/node": ">=13.7.0",
        "long": "^5.0.0"
      },
      "engines": {
        "node": ">=12.0.0"
      }
    },
    "node_modules/proxy-addr": {
      "version": "2.0.7",
      "resolved": "https://registry.npmjs.org/proxy-addr/-/proxy-addr-2.0.7.tgz",
      "integrity": "sha512-llQsMLSUDUPT44jdrU/O37qlnifitDP+ZwrmmZcoSKyLKvtZxpyV0n2/bD/N4tBAAZ/gJEdZU7KMraoK1+XYAg==",
      "license": "MIT",
      "dependencies": {
        "forwarded": "0.2.0",
        "ipaddr.js": "1.9.1"
      },
      "engines": {
        "node": ">= 0.10"
      }
    },
    "node_modules/proxy-from-env": {
      "version": "1.1.0",
      "resolved": "https://registry.npmjs.org/proxy-from-env/-/proxy-from-env-1.1.0.tgz",
      "integrity": "sha512-D+zkORCbA9f1tdWRK0RaCR3GPv50cMxcrz4X8k5LTSUD1Dkw47mKJEZQNunItRTkWwgtaUSo1RVFRIG9ZXiFYg==",
      "license": "MIT"
    },
    "node_modules/qs": {
      "version": "6.14.1",
      "resolved": "https://registry.npmjs.org/qs/-/qs-6.14.1.tgz",
      "integrity": "sha512-4EK3+xJl8Ts67nLYNwqw/dsFVnCf+qR7RgXSK9jEEm9unao3njwMDdmsdvoKBKHzxd7tCYz5e5M+SnMjdtXGQQ==",
      "license": "BSD-3-Clause",
      "dependencies": {
        "side-channel": "^1.1.0"
      },
      "engines": {
        "node": ">=0.6"
      },
      "funding": {
        "url": "https://github.com/sponsors/ljharb"
      }
    },
    "node_modules/range-parser": {
      "version": "1.2.1",
      "resolved": "https://registry.npmjs.org/range-parser/-/range-parser-1.2.1.tgz",
      "integrity": "sha512-Hrgsx+orqoygnmhFbKaHE6c296J+HTAQXoxEF6gNupROmmGJRoyzfG3ccAveqCBrwr/2yxQ5BVd/GTl5agOwSg==",
      "license": "MIT",
      "engines": {
        "node": ">= 0.6"
      }
    },
    "node_modules/raw-body": {
      "version": "2.5.3",
      "resolved": "https://registry.npmjs.org/raw-body/-/raw-body-2.5.3.tgz",
      "integrity": "sha512-s4VSOf6yN0rvbRZGxs8Om5CWj6seneMwK3oDb4lWDH0UPhWcxwOWw5+qk24bxq87szX1ydrwylIOp2uG1ojUpA==",
      "license": "MIT",
      "dependencies": {
        "bytes": "~3.1.2",
        "http-errors": "~2.0.1",
        "iconv-lite": "~0.4.24",
        "unpipe": "~1.0.0"
      },
      "engines": {
        "node": ">= 0.8"
      }
    },
    "node_modules/readable-stream": {
      "version": "3.6.2",
      "resolved": "https://registry.npmjs.org/readable-stream/-/readable-stream-3.6.2.tgz",
      "integrity": "sha512-9u/sniCrY3D5WdsERHzHE4G2YCXqoG5FTHUiCC4SIbr6XcLZBY05ya9EKjYek9O5xOAwjGq+1JdGBAS7Q9ScoA==",
      "license": "MIT",
      "optional": true,
      "dependencies": {
        "inherits": "^2.0.3",
        "string_decoder": "^1.1.1",
        "util-deprecate": "^1.0.1"
      },
      "engines": {
        "node": ">= 6"
      }
    },
    "node_modules/require-directory": {
      "version": "2.1.1",
      "resolved": "https://registry.npmjs.org/require-directory/-/require-directory-2.1.1.tgz",
      "integrity": "sha512-fGxEI7+wsG9xrvdjsrlmL22OMTTiHRwAMroiEeMgq8gzoLC/PQr7RsRDSTLUg/bZAZtF+TVIkHc6/4RIKrui+Q==",
      "license": "MIT",
      "optional": true,
      "engines": {
        "node": ">=0.10.0"
      }
    },
    "node_modules/retry": {
      "version": "0.13.1",
      "resolved": "https://registry.npmjs.org/retry/-/retry-0.13.1.tgz",
      "integrity": "sha512-XQBQ3I8W1Cge0Seh+6gjj03LbmRFWuoszgK9ooCpwYIrhhoO80pfq4cUkU5DkknwfOfFteRwlZ56PYOGYyFWdg==",
      "license": "MIT",
      "optional": true,
      "engines": {
        "node": ">= 4"
      }
    },
    "node_modules/retry-request": {
      "version": "7.0.2",
      "resolved": "https://registry.npmjs.org/retry-request/-/retry-request-7.0.2.tgz",
      "integrity": "sha512-dUOvLMJ0/JJYEn8NrpOaGNE7X3vpI5XlZS/u0ANjqtcZVKnIxP7IgCFwrKTxENw29emmwug53awKtaMm4i9g5w==",
      "license": "MIT",
      "optional": true,
      "dependencies": {
        "@types/request": "^2.48.8",
        "extend": "^3.0.2",
        "teeny-request": "^9.0.0"
      },
      "engines": {
        "node": ">=14"
      }
    },
    "node_modules/safe-buffer": {
      "version": "5.2.1",
      "resolved": "https://registry.npmjs.org/safe-buffer/-/safe-buffer-5.2.1.tgz",
      "integrity": "sha512-rp3So07KcdmmKbGvgaNxQSJr7bGVSVk5S9Eq1F+ppbRo70+YeaDxkw5Dd8NPN+GD6bjnYm2VuPuCXmpuYvmCXQ==",
      "funding": [
        {
          "type": "github",
          "url": "https://github.com/sponsors/feross"
        },
        {
          "type": "patreon",
          "url": "https://www.patreon.com/feross"
        },
        {
          "type": "consulting",
          "url": "https://feross.org/support"
        }
      ],
      "license": "MIT"
    },
    "node_modules/safer-buffer": {
      "version": "2.1.2",
      "resolved": "https://registry.npmjs.org/safer-buffer/-/safer-buffer-2.1.2.tgz",
      "integrity": "sha512-YZo3K82SD7Riyi0E1EQPojLz7kpepnSQI9IyPbHHg1XXXevb5dJI7tpyN2ADxGcQbHG7vcyRHk0cbwqcQriUtg==",
      "license": "MIT"
    },
    "node_modules/scmp": {
      "version": "2.1.0",
      "resolved": "https://registry.npmjs.org/scmp/-/scmp-2.1.0.tgz",
      "integrity": "sha512-o/mRQGk9Rcer/jEEw/yw4mwo3EU/NvYvp577/Btqrym9Qy5/MdWGBqipbALgd2lrdWTJ5/gqDusxfnQBxOxT2Q==",
      "deprecated": "Just use Node.js's crypto.timingSafeEqual()",
      "license": "BSD-3-Clause"
    },
    "node_modules/semver": {
      "version": "7.7.4",
      "resolved": "https://registry.npmjs.org/semver/-/semver-7.7.4.tgz",
      "integrity": "sha512-vFKC2IEtQnVhpT78h1Yp8wzwrf8CM+MzKMHGJZfBtzhZNycRFnXsHk6E5TxIkkMsgNS7mdX3AGB7x2QM2di4lA==",
      "license": "ISC",
      "bin": {
        "semver": "bin/semver.js"
      },
      "engines": {
        "node": ">=10"
      }
    },
    "node_modules/send": {
      "version": "0.19.2",
      "resolved": "https://registry.npmjs.org/send/-/send-0.19.2.tgz",
      "integrity": "sha512-VMbMxbDeehAxpOtWJXlcUS5E8iXh6QmN+BkRX1GARS3wRaXEEgzCcB10gTQazO42tpNIya8xIyNx8fll1OFPrg==",
      "license": "MIT",
      "dependencies": {
        "debug": "2.6.9",
        "depd": "2.0.0",
        "destroy": "1.2.0",
        "encodeurl": "~2.0.0",
        "escape-html": "~1.0.3",
        "etag": "~1.8.1",
        "fresh": "~0.5.2",
        "http-errors": "~2.0.1",
        "mime": "1.6.0",
        "ms": "2.1.3",
        "on-finished": "~2.4.1",
        "range-parser": "~1.2.1",
        "statuses": "~2.0.2"
      },
      "engines": {
        "node": ">= 0.8.0"
      }
    },
    "node_modules/send/node_modules/mime": {
      "version": "1.6.0",
      "resolved": "https://registry.npmjs.org/mime/-/mime-1.6.0.tgz",
      "integrity": "sha512-x0Vn8spI+wuJ1O6S7gnbaQg8Pxh4NNHb7KSINmEWKiPE4RKOplvijn+NkmYmmRgP68mc70j2EbeTFRsrswaQeg==",
      "license": "MIT",
      "bin": {
        "mime": "cli.js"
      },
      "engines": {
        "node": ">=4"
      }
    },
    "node_modules/send/node_modules/ms": {
      "version": "2.1.3",
      "resolved": "https://registry.npmjs.org/ms/-/ms-2.1.3.tgz",
      "integrity": "sha512-6FlzubTLZG3J2a/NVCAleEhjzq5oxgHyaCU9yYXvcLsvoVaHJq/s5xXI6/XXP6tz7R9xAOtHnSO/tXtF3WRTlA==",
      "license": "MIT"
    },
    "node_modules/serve-static": {
      "version": "1.16.3",
      "resolved": "https://registry.npmjs.org/serve-static/-/serve-static-1.16.3.tgz",
      "integrity": "sha512-x0RTqQel6g5SY7Lg6ZreMmsOzncHFU7nhnRWkKgWuMTu5NN0DR5oruckMqRvacAN9d5w6ARnRBXl9xhDCgfMeA==",
      "license": "MIT",
      "dependencies": {
        "encodeurl": "~2.0.0",
        "escape-html": "~1.0.3",
        "parseurl": "~1.3.3",
        "send": "~0.19.1"
      },
      "engines": {
        "node": ">= 0.8.0"
      }
    },
    "node_modules/setprototypeof": {
      "version": "1.2.0",
      "resolved": "https://registry.npmjs.org/setprototypeof/-/setprototypeof-1.2.0.tgz",
      "integrity": "sha512-E5LDX7Wrp85Kil5bhZv46j8jOeboKq5JMmYM3gVGdGH8xFpPWXUMsNrlODCrkoxMEeNi/XZIwuRvY4XNwYMJpw==",
      "license": "ISC"
    },
    "node_modules/side-channel": {
      "version": "1.1.0",
      "resolved": "https://registry.npmjs.org/side-channel/-/side-channel-1.1.0.tgz",
      "integrity": "sha512-ZX99e6tRweoUXqR+VBrslhda51Nh5MTQwou5tnUDgbtyM0dBgmhEDtWGP/xbKn6hqfPRHujUNwz5fy/wbbhnpw==",
      "license": "MIT",
      "dependencies": {
        "es-errors": "^1.3.0",
        "object-inspect": "^1.13.3",
        "side-channel-list": "^1.0.0",
        "side-channel-map": "^1.0.1",
        "side-channel-weakmap": "^1.0.2"
      },
      "engines": {
        "node": ">= 0.4"
      },
      "funding": {
        "url": "https://github.com/sponsors/ljharb"
      }
    },
    "node_modules/side-channel-list": {
      "version": "1.0.0",
      "resolved": "https://registry.npmjs.org/side-channel-list/-/side-channel-list-1.0.0.tgz",
      "integrity": "sha512-FCLHtRD/gnpCiCHEiJLOwdmFP+wzCmDEkc9y7NsYxeF4u7Btsn1ZuwgwJGxImImHicJArLP4R0yX4c2KCrMrTA==",
      "license": "MIT",
      "dependencies": {
        "es-errors": "^1.3.0",
        "object-inspect": "^1.13.3"
      },
      "engines": {
        "node": ">= 0.4"
      },
      "funding": {
        "url": "https://github.com/sponsors/ljharb"
      }
    },
    "node_modules/side-channel-map": {
      "version": "1.0.1",
      "resolved": "https://registry.npmjs.org/side-channel-map/-/side-channel-map-1.0.1.tgz",
      "integrity": "sha512-VCjCNfgMsby3tTdo02nbjtM/ewra6jPHmpThenkTYh8pG9ucZ/1P8So4u4FGBek/BjpOVsDCMoLA/iuBKIFXRA==",
      "license": "MIT",
      "dependencies": {
        "call-bound": "^1.0.2",
        "es-errors": "^1.3.0",
        "get-intrinsic": "^1.2.5",
        "object-inspect": "^1.13.3"
      },
      "engines": {
        "node": ">= 0.4"
      },
      "funding": {
        "url": "https://github.com/sponsors/ljharb"
      }
    },
    "node_modules/side-channel-weakmap": {
      "version": "1.0.2",
      "resolved": "https://registry.npmjs.org/side-channel-weakmap/-/side-channel-weakmap-1.0.2.tgz",
      "integrity": "sha512-WPS/HvHQTYnHisLo9McqBHOJk2FkHO/tlpvldyrnem4aeQp4hai3gythswg6p01oSoTl58rcpiFAjF2br2Ak2A==",
      "license": "MIT",
      "dependencies": {
        "call-bound": "^1.0.2",
        "es-errors": "^1.3.0",
        "get-intrinsic": "^1.2.5",
        "object-inspect": "^1.13.3",
        "side-channel-map": "^1.0.1"
      },
      "engines": {
        "node": ">= 0.4"
      },
      "funding": {
        "url": "https://github.com/sponsors/ljharb"
      }
    },
    "node_modules/statuses": {
      "version": "2.0.2",
      "resolved": "https://registry.npmjs.org/statuses/-/statuses-2.0.2.tgz",
      "integrity": "sha512-DvEy55V3DB7uknRo+4iOGT5fP1slR8wQohVdknigZPMpMstaKJQWhwiYBACJE3Ul2pTnATihhBYnRhZQHGBiRw==",
      "license": "MIT",
      "engines": {
        "node": ">= 0.8"
      }
    },
    "node_modules/stream-events": {
      "version": "1.0.5",
      "resolved": "https://registry.npmjs.org/stream-events/-/stream-events-1.0.5.tgz",
      "integrity": "sha512-E1GUzBSgvct8Jsb3v2X15pjzN1tYebtbLaMg+eBOUOAxgbLoSbT2NS91ckc5lJD1KfLjId+jXJRgo0qnV5Nerg==",
      "license": "MIT",
      "optional": true,
      "dependencies": {
        "stubs": "^3.0.0"
      }
    },
    "node_modules/stream-shift": {
      "version": "1.0.3",
      "resolved": "https://registry.npmjs.org/stream-shift/-/stream-shift-1.0.3.tgz",
      "integrity": "sha512-76ORR0DO1o1hlKwTbi/DM3EXWGf3ZJYO8cXX5RJwnul2DEg2oyoZyjLNoQM8WsvZiFKCRfC1O0J7iCvie3RZmQ==",
      "license": "MIT",
      "optional": true
    },
    "node_modules/string_decoder": {
      "version": "1.3.0",
      "resolved": "https://registry.npmjs.org/string_decoder/-/string_decoder-1.3.0.tgz",
      "integrity": "sha512-hkRX8U1WjJFd8LsDJ2yQ/wWWxaopEsABU1XfkM8A+j0+85JAGppt16cr1Whg6KIbb4okU6Mql6BOj+uup/wKeA==",
      "license": "MIT",
      "optional": true,
      "dependencies": {
        "safe-buffer": "~5.2.0"
      }
    },
    "node_modules/string-width": {
      "version": "4.2.3",
      "resolved": "https://registry.npmjs.org/string-width/-/string-width-4.2.3.tgz",
      "integrity": "sha512-wKyQRQpjJ0sIp62ErSZdGsjMJWsap5oRNihHhu6G7JVO/9jIB6UyevL+tXuOqrng8j/cxKTWyWUwvSTriiZz/g==",
      "license": "MIT",
      "optional": true,
      "dependencies": {
        "emoji-regex": "^8.0.0",
        "is-fullwidth-code-point": "^3.0.0",
        "strip-ansi": "^6.0.1"
      },
      "engines": {
        "node": ">=8"
      }
    },
    "node_modules/strip-ansi": {
      "version": "6.0.1",
      "resolved": "https://registry.npmjs.org/strip-ansi/-/strip-ansi-6.0.1.tgz",
      "integrity": "sha512-Y38VPSHcqkFrCpFnQ9vuSXmquuv5oXOKpGeT6aGrr3o3Gc9AlVa6JBfUSOCnbxGGZF+/0ooI7KrPuUSztUdU5A==",
      "license": "MIT",
      "optional": true,
      "dependencies": {
        "ansi-regex": "^5.0.1"
      },
      "engines": {
        "node": ">=8"
      }
    },
    "node_modules/strnum": {
      "version": "2.1.2",
      "resolved": "https://registry.npmjs.org/strnum/-/strnum-2.1.2.tgz",
      "integrity": "sha512-l63NF9y/cLROq/yqKXSLtcMeeyOfnSQlfMSlzFt/K73oIaD8DGaQWd7Z34X9GPiKqP5rbSh84Hl4bOlLcjiSrQ==",
      "funding": [
        {
          "type": "github",
          "url": "https://github.com/sponsors/NaturalIntelligence"
        }
      ],
      "license": "MIT",
      "optional": true
    },
    "node_modules/stubs": {
      "version": "3.0.0",
      "resolved": "https://registry.npmjs.org/stubs/-/stubs-3.0.0.tgz",
      "integrity": "sha512-PdHt7hHUJKxvTCgbKX9C1V/ftOcjJQgz8BZwNfV5c4B6dcGqlpelTbJ999jBGZ2jYiPAwcX5dP6oBwVlBlUbxw==",
      "license": "MIT",
      "optional": true
    },
    "node_modules/teeny-request": {
      "version": "9.0.0",
      "resolved": "https://registry.npmjs.org/teeny-request/-/teeny-request-9.0.0.tgz",
      "integrity": "sha512-resvxdc6Mgb7YEThw6G6bExlXKkv6+YbuzGg9xuXxSgxJF7Ozs+o8Y9+2R3sArdWdW8nOokoQb1yrpFB0pQK2g==",
      "license": "Apache-2.0",
      "optional": true,
      "dependencies": {
        "http-proxy-agent": "^5.0.0",
        "https-proxy-agent": "^5.0.0",
        "node-fetch": "^2.6.9",
        "stream-events": "^1.0.5",
        "uuid": "^9.0.0"
      },
      "engines": {
        "node": ">=14"
      }
    },
    "node_modules/teeny-request/node_modules/agent-base": {
      "version": "6.0.2",
      "resolved": "https://registry.npmjs.org/agent-base/-/agent-base-6.0.2.tgz",
      "integrity": "sha512-RZNwNclF7+MS/8bDg70amg32dyeZGZxiDuQmZxKLAlQjr3jGyLx+4Kkk58UO7D2QdgFIQCovuSuZESne6RG6XQ==",
      "license": "MIT",
      "optional": true,
      "dependencies": {
        "debug": "4"
      },
      "engines": {
        "node": ">= 6.0.0"
      }
    },
    "node_modules/teeny-request/node_modules/debug": {
      "version": "4.4.3",
      "resolved": "https://registry.npmjs.org/debug/-/debug-4.4.3.tgz",
      "integrity": "sha512-RGwwWnwQvkVfavKVt22FGLw+xYSdzARwm0ru6DhTVA3umU5hZc28V3kO4stgYryrTlLpuvgI9GiijltAjNbcqA==",
      "license": "MIT",
      "optional": true,
      "dependencies": {
        "ms": "^2.1.3"
      },
      "engines": {
        "node": ">=6.0"
      },
      "peerDependenciesMeta": {
        "supports-color": {
          "optional": true
        }
      }
    },
    "node_modules/teeny-request/node_modules/https-proxy-agent": {
      "version": "5.0.1",
      "resolved": "https://registry.npmjs.org/https-proxy-agent/-/https-proxy-agent-5.0.1.tgz",
      "integrity": "sha512-dFcAjpTQFgoLMzC2VwU+C/CbS7uRL0lWmxDITmqm7C+7F0Odmj6s9l6alZc6AELXhrnggM2CeWSXHGOdX2YtwA==",
      "license": "MIT",
      "optional": true,
      "dependencies": {
        "agent-base": "6",
        "debug": "4"
      },
      "engines": {
        "node": ">= 6"
      }
    },
    "node_modules/teeny-request/node_modules/ms": {
      "version": "2.1.3",
      "resolved": "https://registry.npmjs.org/ms/-/ms-2.1.3.tgz",
      "integrity": "sha512-6FlzubTLZG3J2a/NVCAleEhjzq5oxgHyaCU9yYXvcLsvoVaHJq/s5xXI6/XXP6tz7R9xAOtHnSO/tXtF3WRTlA==",
      "license": "MIT",
      "optional": true
    },
    "node_modules/teeny-request/node_modules/uuid": {
      "version": "9.0.1",
      "resolved": "https://registry.npmjs.org/uuid/-/uuid-9.0.1.tgz",
      "integrity": "sha512-b+1eJOlsR9K8HJpow9Ok3fiWOWSIcIzXodvv0rQjVoOVNpWMpxf1wZNpt4y9h10odCNrqnYp1OBzRktckBe3sA==",
      "funding": [
        "https://github.com/sponsors/broofa",
        "https://github.com/sponsors/ctavan"
      ],
      "license": "MIT",
      "optional": true,
      "bin": {
        "uuid": "dist/bin/uuid"
      }
    },
    "node_modules/toidentifier": {
      "version": "1.0.1",
      "resolved": "https://registry.npmjs.org/toidentifier/-/toidentifier-1.0.1.tgz",
      "integrity": "sha512-o5sSPKEkg/DIQNmH43V0/uerLrpzVedkUh8tGNvaeXpfpuwjKenlSox/2O/BTlZUtEe+JG7s5YhEz608PlAHRA==",
      "license": "MIT",
      "engines": {
        "node": ">=0.6"
      }
    },
    "node_modules/tr46": {
      "version": "0.0.3",
      "resolved": "https://registry.npmjs.org/tr46/-/tr46-0.0.3.tgz",
      "integrity": "sha512-N3WMsuqV66lT30CrXNbEjx4GEwlow3v6rr4mCcv6prnfwhS01rkgyFdjPNBYd9br7LpXV1+Emh01fHnq2Gdgrw==",
      "license": "MIT",
      "optional": true
    },
    "node_modules/tslib": {
      "version": "2.8.1",
      "resolved": "https://registry.npmjs.org/tslib/-/tslib-2.8.1.tgz",
      "integrity": "sha512-oJFu94HQb+KVduSUQL7wnpmqnfmLsOA/nAh6b6EH0wCEoK0/mPeXU6c3wKDV83MkOuHPRHtSXKKU99IBazS/2w==",
      "license": "0BSD"
    },
    "node_modules/twilio": {
      "version": "5.12.1",
      "resolved": "https://registry.npmjs.org/twilio/-/twilio-5.12.1.tgz",
      "integrity": "sha512-EhgWS5o+JWqMEl0KgUaN1oAym2Pr7LYYiIlwQdx+u+vACBdwHRzhHAQD6TRKFMciNUTzgBi266ZNpYbFhnEykQ==",
      "license": "MIT",
      "dependencies": {
        "axios": "^1.12.0",
        "dayjs": "^1.11.9",
        "https-proxy-agent": "^5.0.0",
        "jsonwebtoken": "^9.0.2",
        "qs": "^6.14.1",
        "scmp": "^2.1.0",
        "xmlbuilder": "^13.0.2"
      },
      "engines": {
        "node": ">=14.0"
      }
    },
    "node_modules/twilio/node_modules/agent-base": {
      "version": "6.0.2",
      "resolved": "https://registry.npmjs.org/agent-base/-/agent-base-6.0.2.tgz",
      "integrity": "sha512-RZNwNclF7+MS/8bDg70amg32dyeZGZxiDuQmZxKLAlQjr3jGyLx+4Kkk58UO7D2QdgFIQCovuSuZESne6RG6XQ==",
      "license": "MIT",
      "dependencies": {
        "debug": "4"
      },
      "engines": {
        "node": ">= 6.0.0"
      }
    },
    "node_modules/twilio/node_modules/debug": {
      "version": "4.4.3",
      "resolved": "https://registry.npmjs.org/debug/-/debug-4.4.3.tgz",
      "integrity": "sha512-RGwwWnwQvkVfavKVt22FGLw+xYSdzARwm0ru6DhTVA3umU5hZc28V3kO4stgYryrTlLpuvgI9GiijltAjNbcqA==",
      "license": "MIT",
      "dependencies": {
        "ms": "^2.1.3"
      },
      "engines": {
        "node": ">=6.0"
      },
      "peerDependenciesMeta": {
        "supports-color": {
          "optional": true
        }
      }
    },
    "node_modules/twilio/node_modules/https-proxy-agent": {
      "version": "5.0.1",
      "resolved": "https://registry.npmjs.org/https-proxy-agent/-/https-proxy-agent-5.0.1.tgz",
      "integrity": "sha512-dFcAjpTQFgoLMzC2VwU+C/CbS7uRL0lWmxDITmqm7C+7F0Odmj6s9l6alZc6AELXhrnggM2CeWSXHGOdX2YtwA==",
      "license": "MIT",
      "dependencies": {
        "agent-base": "6",
        "debug": "4"
      },
      "engines": {
        "node": ">= 6"
      }
    },
    "node_modules/twilio/node_modules/ms": {
      "version": "2.1.3",
      "resolved": "https://registry.npmjs.org/ms/-/ms-2.1.3.tgz",
      "integrity": "sha512-6FlzubTLZG3J2a/NVCAleEhjzq5oxgHyaCU9yYXvcLsvoVaHJq/s5xXI6/XXP6tz7R9xAOtHnSO/tXtF3WRTlA==",
      "license": "MIT"
    },
    "node_modules/type-is": {
      "version": "1.6.18",
      "resolved": "https://registry.npmjs.org/type-is/-/type-is-1.6.18.tgz",
      "integrity": "sha512-TkRKr9sUTxEH8MdfuCSP7VizJyzRNMjj2J2do2Jr3Kym598JVdEksuzPQCnlFPW4ky9Q+iA+ma9BGm06XQBy8g==",
      "license": "MIT",
      "dependencies": {
        "media-typer": "0.3.0",
        "mime-types": "~2.1.24"
      },
      "engines": {
        "node": ">= 0.6"
      }
    },
    "node_modules/typescript": {
      "version": "5.9.3",
      "resolved": "https://registry.npmjs.org/typescript/-/typescript-5.9.3.tgz",
      "integrity": "sha512-jl1vZzPDinLr9eUt3J/t7V6FgNEw9QjvBPdysz9KfQDD41fQrC2Y4vKQdiaUpFT4bXlb1RHhLpp8wtm6M5TgSw==",
      "dev": true,
      "license": "Apache-2.0",
      "bin": {
        "tsc": "bin/tsc",
        "tsserver": "bin/tsserver"
      },
      "engines": {
        "node": ">=14.17"
      }
    },
    "node_modules/undici-types": {
      "version": "6.21.0",
      "resolved": "https://registry.npmjs.org/undici-types/-/undici-types-6.21.0.tgz",
      "integrity": "sha512-iwDZqg0QAGrg9Rav5H4n0M64c3mkR59cJ6wQp+7C4nI0gsmExaedaYLNO44eT4AtBBwjbTiGPMlt2Md0T9H9JQ==",
      "license": "MIT"
    },
    "node_modules/unpipe": {
      "version": "1.0.0",
      "resolved": "https://registry.npmjs.org/unpipe/-/unpipe-1.0.0.tgz",
      "integrity": "sha512-pjy2bYhSsufwWlKwPc+l3cN7+wuJlK6uz0YdJEOlQDbl6jo/YlPi4mb8agUkVC8BF7V8NuzeyPNqRksA3hztKQ==",
      "license": "MIT",
      "engines": {
        "node": ">= 0.8"
      }
    },
    "node_modules/util-deprecate": {
      "version": "1.0.2",
      "resolved": "https://registry.npmjs.org/util-deprecate/-/util-deprecate-1.0.2.tgz",
      "integrity": "sha512-EPD5q1uXyFxJpCrLnCc1nHnq3gOa6DZBocAIiI2TaSCA7VCJ1UJDMagCzIkXNsUYfD1daK//LTEQ8xiIbrHtcw==",
      "license": "MIT",
      "optional": true
    },
    "node_modules/utils-merge": {
      "version": "1.0.1",
      "resolved": "https://registry.npmjs.org/utils-merge/-/utils-merge-1.0.1.tgz",
      "integrity": "sha512-pMZTvIkT1d+TFGvDOqodOclx0QWkkgi6Tdoa8gC8ffGAAqz9pzPTZWAybbsHHoED/ztMtkv/VoYTYyShUn81hA==",
      "license": "MIT",
      "engines": {
        "node": ">= 0.4.0"
      }
    },
    "node_modules/uuid": {
      "version": "10.0.0",
      "resolved": "https://registry.npmjs.org/uuid/-/uuid-10.0.0.tgz",
      "integrity": "sha512-8XkAphELsDnEGrDxUOHB3RGvXz6TeuYSGEZBOjtTtPm2lwhGBjLgOzLHB63IUWfBpNucQjND6d3AOudO+H3RWQ==",
      "funding": [
        "https://github.com/sponsors/broofa",
        "https://github.com/sponsors/ctavan"
      ],
      "license": "MIT",
      "bin": {
        "uuid": "dist/bin/uuid"
      }
    },
    "node_modules/vary": {
      "version": "1.1.2",
      "resolved": "https://registry.npmjs.org/vary/-/vary-1.1.2.tgz",
      "integrity": "sha512-BNGbWLfd0eUPabhkXUVm0j8uuvREyTh5ovRa/dyow/BqAbZJyC+5fU+IzQOzmAKzYqYRAISoRhdQr3eIZ/PXqg==",
      "license": "MIT",
      "engines": {
        "node": ">= 0.8"
      }
    },
    "node_modules/webidl-conversions": {
      "version": "3.0.1",
      "resolved": "https://registry.npmjs.org/webidl-conversions/-/webidl-conversions-3.0.1.tgz",
      "integrity": "sha512-2JAn3z8AR6rjK8Sm8orRC0h/bcl/DqL7tRPdGZ4I1CjdF+EaMLmYxBHyXuKL849eucPFhvBoxMsflfOb8kxaeQ==",
      "license": "BSD-2-Clause",
      "optional": true
    },
    "node_modules/websocket-driver": {
      "version": "0.7.4",
      "resolved": "https://registry.npmjs.org/websocket-driver/-/websocket-driver-0.7.4.tgz",
      "integrity": "sha512-b17KeDIQVjvb0ssuSDF2cYXSg2iztliJ4B9WdsuB6J952qCPKmnVq4DyW5motImXHDC1cBT/1UezrJVsKw5zjg==",
      "license": "Apache-2.0",
      "dependencies": {
        "http-parser-js": ">=0.5.1",
        "safe-buffer": ">=5.1.0",
        "websocket-extensions": ">=0.1.1"
      },
      "engines": {
        "node": ">=0.8.0"
      }
    },
    "node_modules/websocket-extensions": {
      "version": "0.1.4",
      "resolved": "https://registry.npmjs.org/websocket-extensions/-/websocket-extensions-0.1.4.tgz",
      "integrity": "sha512-OqedPIGOfsDlo31UNwYbCFMSaO9m9G/0faIHj5/dZFDMFqPTcx6UwqyOy3COEaEOg/9VsGIpdqn62W5KhoKSpg==",
      "license": "Apache-2.0",
      "engines": {
        "node": ">=0.8.0"
      }
    },
    "node_modules/whatwg-url": {
      "version": "5.0.0",
      "resolved": "https://registry.npmjs.org/whatwg-url/-/whatwg-url-5.0.0.tgz",
      "integrity": "sha512-saE57nupxk6v3HY35+jzBwYa0rKSy0XR8JSxZPwgLr7ys0IBzhGviA1/TUGJLmSVqs8pb9AnvICXEuOHLprYTw==",
      "license": "MIT",
      "optional": true,
      "dependencies": {
        "tr46": "~0.0.3",
        "webidl-conversions": "^3.0.0"
      }
    },
    "node_modules/wrap-ansi": {
      "version": "7.0.0",
      "resolved": "https://registry.npmjs.org/wrap-ansi/-/wrap-ansi-7.0.0.tgz",
      "integrity": "sha512-YVGIj2kamLSTxw6NsZjoBxfSwsn0ycdesmc4p+Q21c5zPuZ1pl+NfxVdxPtdHvmNVOQ6XSYG4AUtyt/Fi7D16Q==",
      "license": "MIT",
      "optional": true,
      "dependencies": {
        "ansi-styles": "^4.0.0",
        "string-width": "^4.1.0",
        "strip-ansi": "^6.0.0"
      },
      "engines": {
        "node": ">=10"
      },
      "funding": {
        "url": "https://github.com/chalk/wrap-ansi?sponsor=1"
      }
    },
    "node_modules/wrappy": {
      "version": "1.0.2",
      "resolved": "https://registry.npmjs.org/wrappy/-/wrappy-1.0.2.tgz",
      "integrity": "sha512-l4Sp/DRseor9wL6EvV2+TuQn63dMkPjZ/sp9XkghTEbV9KlPS1xUsZ3u7/IQO4wxtcFB4bgpQPRcR3QCvezPcQ==",
      "license": "ISC",
      "optional": true
    },
    "node_modules/xmlbuilder": {
      "version": "13.0.2",
      "resolved": "https://registry.npmjs.org/xmlbuilder/-/xmlbuilder-13.0.2.tgz",
      "integrity": "sha512-Eux0i2QdDYKbdbA6AM6xE4m6ZTZr4G4xF9kahI2ukSEMCzwce2eX9WlTI5J3s+NU7hpasFsr8hWIONae7LluAQ==",
      "license": "MIT",
      "engines": {
        "node": ">=6.0"
      }
    },
    "node_modules/y18n": {
      "version": "5.0.8",
      "resolved": "https://registry.npmjs.org/y18n/-/y18n-5.0.8.tgz",
      "integrity": "sha512-0pfFzegeDWJHJIAmTLRP2DwHjdF5s7jo9tuztdQxAhINCdvS+3nGINqPd00AphqJR/0LhANUS6/+7SCb98YOfA==",
      "license": "ISC",
      "optional": true,
      "engines": {
        "node": ">=10"
      }
    },
    "node_modules/yallist": {
      "version": "4.0.0",
      "resolved": "https://registry.npmjs.org/yallist/-/yallist-4.0.0.tgz",
      "integrity": "sha512-3wdGidZyq5PB084XLES5TpOSRA3wjXAlIWMhum2kRcv/41Sn2emQ0dycQW4uZXLejwKvg6EsvbdlVL+FYEct7A==",
      "license": "ISC"
    },
    "node_modules/yargs": {
      "version": "17.7.2",
      "resolved": "https://registry.npmjs.org/yargs/-/yargs-17.7.2.tgz",
      "integrity": "sha512-7dSzzRQ++CKnNI/krKnYRV7JKKPUXMEh61soaHKg9mrWEhzFWhFnxPxGl+69cD1Ou63C13NUPCnmIcrvqCuM6w==",
      "license": "MIT",
      "optional": true,
      "dependencies": {
        "cliui": "^8.0.1",
        "escalade": "^3.1.1",
        "get-caller-file": "^2.0.5",
        "require-directory": "^2.1.1",
        "string-width": "^4.2.3",
        "y18n": "^5.0.5",
        "yargs-parser": "^21.1.1"
      },
      "engines": {
        "node": ">=12"
      }
    },
    "node_modules/yargs-parser": {
      "version": "21.1.1",
      "resolved": "https://registry.npmjs.org/yargs-parser/-/yargs-parser-21.1.1.tgz",
      "integrity": "sha512-tVpsJW7DdjecAiFpbIB1e3qxIQsE6NoPc5/eTdrbbIC4h0LVsWhnoa3g+m2HclBIujHzsxZ4VJVA+GUuc2/LBw==",
      "license": "ISC",
      "optional": true,
      "engines": {
        "node": ">=12"
      }
    },
    "node_modules/yocto-queue": {
      "version": "0.1.0",
      "resolved": "https://registry.npmjs.org/yocto-queue/-/yocto-queue-0.1.0.tgz",
      "integrity": "sha512-rVksvsnNCdJ/ohGc6xgPwyN8eheCxsiLM8mxuE/t/mOVqJewPuO1miLpTHQiRgTKCLexL4MeAFVagts7HmNZ2Q==",
      "license": "MIT",
      "optional": true,
      "engines": {
        "node": ">=10"
      },
      "funding": {
        "url": "https://github.com/sponsors/sindresorhus"
      }
    }
  }
}

```

## backend/functions/package.json

```json
{
  "name": "arrival-uk-functions",
  "private": true,
  "engines": {
    "node": "20"
  },
  "main": "lib/index.js",
  "scripts": {
    "build": "tsc -p .",
    "lint": "tsc -p . --noEmit",
    "serve": "firebase emulators:start --only functions",
    "deploy": "firebase deploy --only functions"
  },
  "dependencies": {
    "@sendgrid/mail": "^8.1.5",
    "firebase-admin": "^12.6.0",
    "firebase-functions": "^5.1.1",
    "twilio": "^5.5.3"
  },
  "devDependencies": {
    "typescript": "^5.6.3"
  }
}

```

## backend/functions/src/auth.ts

```ts
import * as admin from "firebase-admin";
import * as functions from "firebase-functions";

if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();

function generateReferralCode(userId: string): string {
  const prefix = userId.slice(0, 4).toUpperCase();
  const suffix = Math.random().toString(36).slice(2, 5).toUpperCase();
  return `${prefix}${suffix}`;
}

async function trackAnalyticsEvent(
  userId: string,
  eventType: string,
  properties: Record<string, unknown>
): Promise<void> {
  await db.collection("analytics").doc("events").collection("items").add({
    userId,
    eventType,
    properties,
    platform: "backend",
    appVersion: "cloud_function",
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });
}

async function sendWelcomeEmail(email?: string | null, displayName?: string | null): Promise<void> {
  if (!email) return;
  functions.logger.info("Welcome email placeholder", {
    email,
    displayName: displayName ?? "",
  });
}

export const onUserCreate = functions.auth.user().onCreate(async (user) => {
  const authProvider = (() => {
    const providerId = user.providerData?.[0]?.providerId;
    if (providerId === "google.com") return "google";
    if (providerId === "apple.com") return "apple";
    return "email";
  })();

  await db.collection("users").doc(user.uid).set({
    userId: user.uid,
    email: user.email ?? null,
    displayName: user.displayName ?? null,
    photoURL: user.photoURL ?? null,
    authProvider,
    profile: {
      university: null,
      course: null,
      studyLevel: null,
      city: null,
      arrivalDate: null,
      nationality: null,
      homeCurrency: null,
      accommodationType: null,
      visaType: null,
    },
    preferences: {
      language: "en",
      notifications: {
        taskReminders: true,
        weeklyDigest: true,
        productUpdates: false,
      },
      privacy: {
        allowAnalytics: true,
        allowPersonalizedAds: true,
        dataSharing: false,
      },
    },
    progress: {
      completedTasks: [],
      totalTasks: 0,
      completionRate: 0,
      lastActivityDate: admin.firestore.FieldValue.serverTimestamp(),
    },
    engagement: {
      daysSinceSignup: 0,
      loginCount: 1,
      lastLoginDate: admin.firestore.FieldValue.serverTimestamp(),
      referralCode: generateReferralCode(user.uid),
      referredBy: null,
    },
    monetization: {
      isPremium: false,
      premiumExpiryDate: null,
      lifetimeValue: 0,
      adImpressions: 0,
      affiliateClicks: 0,
    },
    metadata: {
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      version: 1,
      platform: "unknown",
      appVersion: "unknown",
    },
  }, { merge: true });

  await sendWelcomeEmail(user.email, user.displayName);
  await trackAnalyticsEvent(user.uid, "user_registered", {
    authProvider,
    email: user.email ?? null,
  });

  functions.logger.info("User profile document initialized", { userId: user.uid });
});

export const onUserDelete = functions.auth.user().onDelete(async (user) => {
  const userId = user.uid;

  await db.collection("users").doc(userId).delete();

  const customTasks = await db.collection("users").doc(userId).collection("customTasks").get();
  await Promise.all(customTasks.docs.map((doc) => doc.ref.delete()));

  const progress = await db.collection("users").doc(userId).collection("progress").get();
  await Promise.all(progress.docs.map((doc) => doc.ref.delete()));

  functions.logger.info("Deleted user and nested local data", { userId });
});

export const trackLogin = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Authentication required");
  }

  const userId = context.auth.uid;
  const platform = (data?.platform as string) ?? "unknown";
  const appVersion = (data?.appVersion as string) ?? "unknown";

  await db.collection("users").doc(userId).set({
    engagement: {
      loginCount: admin.firestore.FieldValue.increment(1),
      lastLoginDate: admin.firestore.FieldValue.serverTimestamp(),
    },
    metadata: {
      platform,
      appVersion,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
  }, { merge: true });

  return { success: true };
});

export const verifyUser = functions.https.onCall(async (_data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Authentication required");
  }

  const userId = context.auth.uid;
  const snapshot = await db.collection("users").doc(userId).get();

  if (!snapshot.exists) {
    throw new functions.https.HttpsError("not-found", "User profile not found");
  }

  return {
    userId,
    ...snapshot.data(),
  };
});

```

## backend/functions/src/email.ts

```ts
import * as admin from "firebase-admin";
import * as functions from "firebase-functions";

if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();
const CUSTOM_EMAIL_RATE_LIMIT_WINDOW_MS = 60 * 60 * 1000;
const CUSTOM_EMAIL_RATE_LIMIT_MAX = 20;
const ALLOWED_CUSTOM_EMAIL_TEMPLATES = new Set([
  "support_followup",
  "broadcast_update",
  "maintenance_notice",
]);
const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

type MailPayload = {
  to: string;
  from: string;
  subject: string;
  html: string;
};

type SendGridClient = {
  setApiKey: (key: string) => void;
  send: (mail: MailPayload) => Promise<unknown>;
};

function getSendGridClient(): SendGridClient | null {
  try {
    // Optional runtime dependency. Keeps scaffold compile-safe before credentials/deps are installed.
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const mailer = require("@sendgrid/mail") as SendGridClient;
    const apiKey = (process.env.SENDGRID_API_KEY ||
      functions.config()?.sendgrid?.api_key) as string | undefined;
    if (!apiKey) return null;
    mailer.setApiKey(apiKey);
    return mailer;
  } catch {
    return null;
  }
}

function fromEmail(): string {
  return ((process.env.SENDGRID_FROM_EMAIL ||
    functions.config()?.sendgrid?.from_email) as string | undefined) ?? "noreply@arrivaluk.app";
}

function appName(): string {
  return ((process.env.APP_NAME ||
    functions.config()?.app?.name) as string | undefined) ?? "Arrival UK";
}

function appURL(): string {
  return ((process.env.APP_URL ||
    functions.config()?.app?.url) as string | undefined) ?? "https://arrivaluk.app";
}

function welcomeHTML(displayName: string): string {
  return `
  <div style="font-family:-apple-system,Arial,sans-serif;line-height:1.5;color:#111827;">
    <h2>Welcome to ${appName()}</h2>
    <p>Hi ${displayName},</p>
    <p>Thanks for joining. We’ll help you plan your UK arrival step by step.</p>
    <p><a href="${appURL()}" style="display:inline-block;padding:10px 16px;border-radius:8px;background:#6366F1;color:#fff;text-decoration:none;">Open ${appName()}</a></p>
  </div>
  `.trim();
}

function supportCreatedHTML(displayName: string, ticketId: string, subject: string): string {
  return `
  <div style="font-family:-apple-system,Arial,sans-serif;line-height:1.5;color:#111827;">
    <h2>Support Ticket Created</h2>
    <p>Hi ${displayName},</p>
    <p>We received your request and will reply soon.</p>
    <p><b>Ticket:</b> #${ticketId}<br/><b>Subject:</b> ${subject}</p>
  </div>
  `.trim();
}

async function sendMail(payload: MailPayload): Promise<void> {
  const client = getSendGridClient();
  if (!client) {
    functions.logger.warn("SendGrid not configured; email skipped", {
      to: payload.to,
      subject: payload.subject,
    });
    return;
  }

  await client.send(payload);
}

function safeString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function parseTemplateVariables(value: unknown): Record<string, string> {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};

  const raw = value as Record<string, unknown>;
  const output: Record<string, string> = {};
  for (const [key, current] of Object.entries(raw)) {
    if (typeof current !== "string") continue;
    const normalizedKey = key.trim();
    if (!normalizedKey) continue;
    output[normalizedKey] = current.trim().slice(0, 500);
  }
  return output;
}

function isPrivilegedCaller(context: functions.https.CallableContext): boolean {
  const token = context.auth?.token as Record<string, unknown> | undefined;
  if (!token) return false;
  if (token.admin === true) return true;
  const role = typeof token.role === "string" ? token.role.toLowerCase() : "";
  return role === "admin" || role === "owner";
}

async function enforceRateLimit(
  namespace: string,
  userId: string,
  maxRequests: number,
  windowMs: number
): Promise<void> {
  const nowMs = Date.now();
  const ref = db.collection("rateLimits").doc(`${namespace}_${userId}`);

  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const data = snapshot.data() as { count?: number; windowStartMs?: number } | undefined;
    const previousWindowStart = Number(data?.windowStartMs ?? 0);
    const previousCount = Number(data?.count ?? 0);
    const windowStillOpen = nowMs - previousWindowStart < windowMs;

    const nextWindowStart = windowStillOpen ? previousWindowStart : nowMs;
    const nextCount = windowStillOpen ? previousCount + 1 : 1;

    if (windowStillOpen && previousCount >= maxRequests) {
      throw new functions.https.HttpsError(
        "resource-exhausted",
        "Rate limit exceeded for custom email sending."
      );
    }

    transaction.set(
      ref,
      {
        count: nextCount,
        windowStartMs: nextWindowStart,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  });
}

function renderCustomTemplate(
  templateKey: string,
  variables: Record<string, string>
): { subject: string; html: string } {
  const recipientName = variables.recipientName || "there";
  const ctaURL = variables.ctaURL || appURL();
  const message = variables.message || "We have an update for you.";
  const appLabel = appName();

  if (templateKey === "support_followup") {
    return {
      subject: `${appLabel} support follow-up`,
      html: `
      <div style="font-family:-apple-system,Arial,sans-serif;line-height:1.5;color:#111827;">
        <h2>Support Follow-up</h2>
        <p>Hi ${recipientName},</p>
        <p>${message}</p>
      </div>
      `.trim(),
    };
  }

  if (templateKey === "maintenance_notice") {
    return {
      subject: `${appLabel} scheduled maintenance`,
      html: `
      <div style="font-family:-apple-system,Arial,sans-serif;line-height:1.5;color:#111827;">
        <h2>Scheduled Maintenance</h2>
        <p>Hi ${recipientName},</p>
        <p>${message}</p>
        <p>We appreciate your patience.</p>
      </div>
      `.trim(),
    };
  }

  return {
    subject: `${appLabel} update`,
    html: `
    <div style="font-family:-apple-system,Arial,sans-serif;line-height:1.5;color:#111827;">
      <h2>Update from ${appLabel}</h2>
      <p>Hi ${recipientName},</p>
      <p>${message}</p>
      <p><a href="${ctaURL}" style="display:inline-block;padding:10px 16px;border-radius:8px;background:#6366F1;color:#fff;text-decoration:none;">Open ${appLabel}</a></p>
    </div>
    `.trim(),
  };
}

export const sendWelcomeEmailOnSignup = functions.auth.user().onCreate(async (user) => {
  if (!user.email) return;

  try {
    await sendMail({
      to: user.email,
      from: fromEmail(),
      subject: `Welcome to ${appName()}`,
      html: welcomeHTML(user.displayName ?? "there"),
    });
  } catch (error) {
    functions.logger.error("Failed to send welcome email", {
      userId: user.uid,
      error: error instanceof Error ? error.message : "unknown_error",
    });
  }
});

export const sendWeeklyDigestEmail = functions.pubsub
  .schedule("every monday 09:00")
  .timeZone("Europe/London")
  .onRun(async () => {
    const users = await db
      .collection("users")
      .where("preferences.notifications.weeklyDigest", "==", true)
      .limit(1000)
      .get();

    if (users.empty) return null;

    for (const userDoc of users.docs) {
      const user = userDoc.data();
      const to = user.email as string | undefined;
      if (!to) continue;

      const displayName = (user.displayName as string | undefined) ?? "there";
      const completedCount = Array.isArray(user.progress?.completedTasks)
        ? user.progress.completedTasks.length
        : 0;

      const totalTasks = Number(user.progress?.totalTasks ?? 0);
      const percent = totalTasks > 0 ? Math.round((completedCount / totalTasks) * 100) : 0;

      const html = `
      <div style="font-family:-apple-system,Arial,sans-serif;line-height:1.5;color:#111827;">
        <h2>Your Weekly Progress</h2>
        <p>Hi ${displayName},</p>
        <p>You have completed <b>${completedCount}</b> tasks so far (${percent}%).</p>
        <p><a href="${appURL()}" style="display:inline-block;padding:10px 16px;border-radius:8px;background:#6366F1;color:#fff;text-decoration:none;">Continue</a></p>
      </div>
      `.trim();

      try {
        await sendMail({
          to,
          from: fromEmail(),
          subject: "Your weekly checklist digest",
          html,
        });
      } catch (error) {
        functions.logger.error("Failed to send weekly digest", {
          userId: userDoc.id,
          error: error instanceof Error ? error.message : "unknown_error",
        });
      }
    }

    return null;
  });

export const sendSupportTicketConfirmation = functions.firestore
  .document("support/tickets/items/{ticketId}")
  .onCreate(async (snapshot, context) => {
    const ticket = snapshot.data();
    const userId = ticket.userId as string | undefined;
    if (!userId) return;

    const userDoc = await db.collection("users").doc(userId).get();
    const userData = userDoc.data();
    const to = userData?.email as string | undefined;
    if (!to) return;

    try {
      await sendMail({
        to,
        from: fromEmail(),
        subject: `Support ticket #${context.params.ticketId} created`,
        html: supportCreatedHTML(
          (userData?.displayName as string | undefined) ?? "there",
          context.params.ticketId,
          (ticket.subject as string | undefined) ?? "Support request"
        ),
      });
    } catch (error) {
      functions.logger.error("Failed to send support ticket confirmation", {
        ticketId: context.params.ticketId,
        error: error instanceof Error ? error.message : "unknown_error",
      });
    }
  });

export const sendCustomEmail = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Authentication required");
  }

  if (!isPrivilegedCaller(context)) {
    throw new functions.https.HttpsError("permission-denied", "Admin privileges required");
  }

  const to = safeString(data?.to);
  const templateKey = safeString(data?.templateKey).toLowerCase();
  const variables = parseTemplateVariables(data?.variables);

  if (!to || !templateKey) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Fields `to` and `templateKey` are required"
    );
  }

  if (!EMAIL_PATTERN.test(to)) {
    throw new functions.https.HttpsError("invalid-argument", "Recipient email is invalid");
  }

  if (!ALLOWED_CUSTOM_EMAIL_TEMPLATES.has(templateKey)) {
    throw new functions.https.HttpsError("invalid-argument", "Unsupported email template key");
  }

  await enforceRateLimit(
    "custom_email",
    context.auth.uid,
    CUSTOM_EMAIL_RATE_LIMIT_MAX,
    CUSTOM_EMAIL_RATE_LIMIT_WINDOW_MS
  );

  const rendered = renderCustomTemplate(templateKey, variables);

  try {
    await sendMail({
      to,
      from: fromEmail(),
      subject: rendered.subject,
      html: rendered.html,
    });
    return {
      success: true,
      templateKey,
    };
  } catch (error) {
    functions.logger.error("Failed to send custom email", {
      userId: context.auth.uid,
      templateKey,
      error: error instanceof Error ? error.message : "unknown_error",
    });
    throw new functions.https.HttpsError("internal", "Failed to send email");
  }
});

```

## backend/functions/src/index.ts

```ts
export {
  onUserCreate,
  onUserDelete,
  trackLogin,
  verifyUser,
} from "./auth";

export {
  scheduleTaskNotifications,
  sendQueuedNotifications,
  registerDeviceToken,
  unregisterDeviceToken,
} from "./notifications";

export {
  sendWelcomeEmailOnSignup,
  sendWeeklyDigestEmail,
  sendSupportTicketConfirmation,
  sendCustomEmail,
} from "./email";

export { sendSMSReminder } from "./sms";

export {
  processProfilePicture,
  cleanupUserStorage,
} from "./storage";

```

## backend/functions/src/notifications.ts

```ts
import * as admin from "firebase-admin";
import * as functions from "firebase-functions";

if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();
const messaging = admin.messaging();

type TaskReminderRecord = {
  userId: string;
  type: "task_reminder";
  title: string;
  body: string;
  data: Record<string, string>;
  scheduledFor: admin.firestore.Timestamp;
  sent: boolean;
  sentAt?: admin.firestore.FieldValue;
  error?: string;
};

type ContentTask = {
  id: string;
  categoryId?: string;
  title?: string;
  timing?: string;
  priority?: string;
  isPublished?: boolean;
};

function parseTimingToDays(timing?: string): number {
  if (!timing) return 0;
  const lower = timing.toLowerCase();
  if (lower.includes("month") && lower.includes("before")) return 30;
  if (lower.includes("week") && lower.includes("before")) return 7;
  if (lower.includes("first week")) return 0;
  if (lower.includes("first month")) return 0;
  return 0;
}

function safeString(value: unknown, fallback: string): string {
  return typeof value === "string" && value.trim().length > 0 ? value : fallback;
}

function completedTaskSetFromUserData(userData: admin.firestore.DocumentData): Set<string> {
  const completed = userData?.progress?.completedTasks;
  if (!Array.isArray(completed)) return new Set<string>();
  return new Set(completed.filter((id: unknown) => typeof id === "string"));
}

function queueDocumentID(userId: string, taskId: string, sendAt: Date): string {
  const dayKey = sendAt.toISOString().slice(0, 10);
  return `${userId}_${taskId}_${dayKey}`.replace(/[^A-Za-z0-9_-]/g, "_");
}

function isAlreadyExistsError(error: unknown): boolean {
  const code = (error as { code?: string | number })?.code;
  return code === 6 || code === "6" || code === "already-exists";
}

async function queueReminder(
  userId: string,
  task: ContentTask,
  daysUntilArrival: number
): Promise<void> {
  const now = new Date();
  const sendAt = new Date(now);
  sendAt.setHours(9, 0, 0, 0);

  // If it's already past 9AM local, push to tomorrow.
  if (sendAt <= now) {
    sendAt.setDate(sendAt.getDate() + 1);
  }

  const title = task.priority?.toLowerCase() === "must do" ? "⚠️ Important task" : "Task reminder";
  const body = safeString(task.title, "You have an upcoming checklist task.");

  const doc: TaskReminderRecord = {
    userId,
    type: "task_reminder",
    title,
    body,
    data: {
      type: "task_reminder",
      taskId: task.id,
      categoryId: safeString(task.categoryId, "unknown"),
      daysUntilArrival: String(daysUntilArrival),
    },
    scheduledFor: admin.firestore.Timestamp.fromDate(sendAt),
    sent: false,
  };

  const queueRef = db
    .collection("notifications")
    .doc("queue")
    .collection("pending")
    .doc(queueDocumentID(userId, task.id, sendAt));

  try {
    await queueRef.create(doc);
  } catch (error) {
    if (isAlreadyExistsError(error)) {
      return;
    }
    throw error;
  }
}

async function getPublishedTasks(): Promise<ContentTask[]> {
  // This follows the current scaffold's nested "items" convention.
  const snapshot = await db
    .collection("content")
    .doc("tasks")
    .collection("items")
    .where("isPublished", "==", true)
    .get();

  return snapshot.docs.map((doc) => ({
    id: doc.id,
    ...(doc.data() as Omit<ContentTask, "id">),
  }));
}

export const scheduleTaskNotifications = functions.pubsub
  .schedule("every day 08:00")
  .timeZone("Europe/London")
  .onRun(async () => {
    const minimumArrivalDate = admin.firestore.Timestamp.fromDate(new Date("2000-01-01T00:00:00.000Z"));
    const usersSnapshot = await db
      .collection("users")
      .where("preferences.notifications.taskReminders", "==", true)
      .where("profile.arrivalDate", ">=", minimumArrivalDate)
      .get();
    if (usersSnapshot.empty) return null;

    const allTasks = await getPublishedTasks();
    if (allTasks.length === 0) return null;

    const now = new Date();
    now.setHours(0, 0, 0, 0);

    for (const userDoc of usersSnapshot.docs) {
      const userId = userDoc.id;
      const userData = userDoc.data();

      const arrivalTs = userData.profile?.arrivalDate as admin.firestore.Timestamp | undefined;
      if (!arrivalTs) continue;

      const arrivalDate = arrivalTs.toDate();
      const daysUntilArrival = Math.ceil(
        (arrivalDate.getTime() - now.getTime()) / (1000 * 60 * 60 * 24)
      );

      const completedSet = completedTaskSetFromUserData(userData);

      for (const task of allTasks) {
        if (!task.id || completedSet.has(task.id)) continue;
        const dueDays = parseTimingToDays(task.timing);

        // Send reminder at due point and one day before the due point.
        const shouldRemind = daysUntilArrival <= dueDays && daysUntilArrival >= dueDays - 1;
        if (!shouldRemind) continue;

        await queueReminder(userId, task, daysUntilArrival);
      }
    }

    functions.logger.info("Scheduled task reminders");
    return null;
  });

export const sendQueuedNotifications = functions.pubsub
  .schedule("every 1 hours")
  .onRun(async () => {
    const now = admin.firestore.Timestamp.now();
    const pending = await db
      .collection("notifications")
      .doc("queue")
      .collection("pending")
      .where("sent", "==", false)
      .where("scheduledFor", "<=", now)
      .limit(100)
      .get();

    if (pending.empty) return null;

    const tokenCache = new Map<string, string | null>();
    const tokenForUser = async (userId: string): Promise<string | null> => {
      if (tokenCache.has(userId)) return tokenCache.get(userId) ?? null;
      const userDoc = await db.collection("users").doc(userId).get();
      const token = safeString(userDoc.data()?.fcmToken, "");
      const normalized = token || null;
      tokenCache.set(userId, normalized);
      return normalized;
    };

    for (const notifDoc of pending.docs) {
      const notif = notifDoc.data() as TaskReminderRecord;
      try {
        const token = await tokenForUser(notif.userId);

        if (!token) {
          await notifDoc.ref.update({
            sent: true,
            sentAt: admin.firestore.FieldValue.serverTimestamp(),
            error: "missing_fcm_token",
          });
          continue;
        }

        await messaging.send({
          token,
          notification: {
            title: notif.title,
            body: notif.body,
          },
          data: notif.data,
          apns: {
            payload: {
              aps: {
                sound: "default",
                badge: 1,
              },
            },
          },
        });

        await notifDoc.ref.update({
          sent: true,
          sentAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      } catch (error) {
        const message = error instanceof Error ? error.message : "unknown_error";
        await notifDoc.ref.update({
          sent: true,
          error: message,
        });
        functions.logger.error("Failed to send queued notification", {
          notificationId: notifDoc.id,
          message,
        });
      }
    }

    return null;
  });

export const registerDeviceToken = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Authentication required");
  }

  const token = safeString(data?.fcmToken, "");
  if (!token) {
    throw new functions.https.HttpsError("invalid-argument", "fcmToken is required");
  }

  const platform = safeString(data?.platform, "unknown");

  await db.collection("users").doc(context.auth.uid).set({
    fcmToken: token,
    metadata: {
      platform,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
  }, { merge: true });

  return { success: true };
});

export const unregisterDeviceToken = functions.https.onCall(async (_data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Authentication required");
  }

  await db.collection("users").doc(context.auth.uid).update({
    fcmToken: admin.firestore.FieldValue.delete(),
    "metadata.updatedAt": admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true };
});

```

## backend/functions/src/sms.ts

```ts
import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();
const SMS_RATE_LIMIT_WINDOW_MS = 60 * 60 * 1000;
const SMS_RATE_LIMIT_MAX = 10;
const E164_PHONE_PATTERN = /^\+[1-9]\d{7,14}$/;

type TwilioClient = {
  messages: {
    create: (args: { body: string; from: string; to: string }) => Promise<{ sid: string }>;
  };
};

function getTwilioClient(): TwilioClient | null {
  try {
    const accountSid = (process.env.TWILIO_ACCOUNT_SID ||
      functions.config()?.twilio?.account_sid) as string | undefined;
    const authToken = (process.env.TWILIO_AUTH_TOKEN ||
      functions.config()?.twilio?.auth_token) as string | undefined;
    if (!accountSid || !authToken) return null;

    // Optional runtime dependency.
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const twilioFactory = require("twilio") as (sid: string, token: string) => TwilioClient;
    return twilioFactory(accountSid, authToken);
  } catch {
    return null;
  }
}

function fromPhone(): string | null {
  const value = (process.env.TWILIO_PHONE_NUMBER ||
    functions.config()?.twilio?.phone_number) as string | undefined;
  return value?.trim() ? value.trim() : null;
}

function safeString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function isPrivilegedCaller(context: functions.https.CallableContext): boolean {
  const token = context.auth?.token as Record<string, unknown> | undefined;
  if (!token) return false;
  if (token.admin === true) return true;
  const role = typeof token.role === "string" ? token.role.toLowerCase() : "";
  return role === "admin" || role === "owner";
}

async function enforceRateLimit(
  namespace: string,
  userId: string,
  maxRequests: number,
  windowMs: number
): Promise<void> {
  const nowMs = Date.now();
  const ref = db.collection("rateLimits").doc(`${namespace}_${userId}`);

  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const data = snapshot.data() as { count?: number; windowStartMs?: number } | undefined;
    const previousWindowStart = Number(data?.windowStartMs ?? 0);
    const previousCount = Number(data?.count ?? 0);
    const windowStillOpen = nowMs - previousWindowStart < windowMs;

    const nextWindowStart = windowStillOpen ? previousWindowStart : nowMs;
    const nextCount = windowStillOpen ? previousCount + 1 : 1;

    if (windowStillOpen && previousCount >= maxRequests) {
      throw new functions.https.HttpsError(
        "resource-exhausted",
        "Rate limit exceeded for SMS sending."
      );
    }

    transaction.set(
      ref,
      {
        count: nextCount,
        windowStartMs: nextWindowStart,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  });
}

export const sendSMSReminder = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Authentication required");
  }

  if (!isPrivilegedCaller(context)) {
    throw new functions.https.HttpsError("permission-denied", "Admin privileges required");
  }

  const to = safeString(data?.phoneNumber);
  const body = safeString(data?.message);

  if (!to || !body) {
    throw new functions.https.HttpsError("invalid-argument", "phoneNumber and message are required");
  }

  if (!E164_PHONE_PATTERN.test(to)) {
    throw new functions.https.HttpsError("invalid-argument", "phoneNumber must be E.164 format");
  }

  if (body.length > 320) {
    throw new functions.https.HttpsError("invalid-argument", "message exceeds maximum length");
  }

  await enforceRateLimit(
    "custom_sms",
    context.auth.uid,
    SMS_RATE_LIMIT_MAX,
    SMS_RATE_LIMIT_WINDOW_MS
  );

  const client = getTwilioClient();
  const from = fromPhone();

  if (!client || !from) {
    functions.logger.warn("Twilio not configured; SMS skipped", {
      to,
      userId: context.auth.uid,
    });
    return { success: false, skipped: true, reason: "twilio_not_configured" };
  }

  try {
    const result = await client.messages.create({
      body,
      from,
      to,
    });
    return { success: true, sid: result.sid };
  } catch (error) {
    functions.logger.error("SMS send failed", {
      to,
      userId: context.auth.uid,
      error: error instanceof Error ? error.message : "unknown_error",
    });
    throw new functions.https.HttpsError("internal", "Failed to send SMS");
  }
});

```

## backend/functions/src/storage.ts

```ts
import * as admin from "firebase-admin";
import * as functions from "firebase-functions";

if (admin.apps.length === 0) {
  admin.initializeApp();
}

const storage = admin.storage();

function isProfileImagePath(filePath?: string): boolean {
  if (!filePath) return false;
  return /users\/[^/]+\/profile\/.+/.test(filePath);
}

function isImageContentType(contentType?: string): boolean {
  return !!contentType && contentType.startsWith("image/");
}

/**
 * Lightweight storage hook:
 * - validates profile image path/content type
 * - normalizes cache metadata
 *
 * Note: Image resizing pipeline is intentionally left off by default to avoid
 * hard runtime dependency on native image libraries. Add sharp/imagemagick in
 * a dedicated rollout if needed.
 */
export const processProfilePicture = functions.storage.object().onFinalize(async (object) => {
  const filePath = object.name;
  const contentType = object.contentType;
  const bucketName = object.bucket;

  if (!filePath || !isProfileImagePath(filePath) || !isImageContentType(contentType) || !bucketName) {
    return;
  }

  try {
    const bucket = storage.bucket(bucketName);
    const file = bucket.file(filePath);
    await file.setMetadata({
      contentType: contentType,
      cacheControl: "public, max-age=31536000, immutable",
      metadata: {
        processedBy: "processProfilePicture",
        processedAt: new Date().toISOString(),
      },
    });

    functions.logger.info("Profile image metadata normalized", { filePath });
  } catch (error) {
    functions.logger.error("Failed to process profile image", {
      filePath,
      error: error instanceof Error ? error.message : "unknown_error",
    });
  }
});

/**
 * Cleanup storage when auth user is removed.
 */
export const cleanupUserStorage = functions.auth.user().onDelete(async (user) => {
  const userId = user.uid;
  const bucket = storage.bucket();

  try {
    const [files] = await bucket.getFiles({
      prefix: `users/${userId}/`,
    });

    if (files.length === 0) {
      functions.logger.info("No storage files found for deleted user", { userId });
      return;
    }

    await Promise.all(files.map((file) => file.delete()));
    functions.logger.info("Deleted storage files for user", {
      userId,
      count: files.length,
    });
  } catch (error) {
    functions.logger.error("Failed to cleanup user storage", {
      userId,
      error: error instanceof Error ? error.message : "unknown_error",
    });
  }
});

```

## backend/functions/tsconfig.json

```json
{
  "compilerOptions": {
    "module": "commonjs",
    "target": "es2022",
    "lib": ["es2022"],
    "outDir": "lib",
    "rootDir": "src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "sourceMap": true
  },
  "include": ["src"]
}

```

## backend/storage.rules

```text
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    function isSignedIn() {
      return request.auth != null;
    }

    function isOwner(userId) {
      return isSignedIn() && request.auth.uid == userId;
    }

    function isImage() {
      return request.resource.contentType.matches('image/.*');
    }

    function isPDF() {
      return request.resource.contentType == 'application/pdf';
    }

    // User profile images
    match /users/{userId}/profile/{fileName} {
      allow read: if isOwner(userId);
      allow write: if isOwner(userId)
                   && request.resource.size < 5 * 1024 * 1024
                   && isImage();
    }

    // User private documents
    match /users/{userId}/documents/{fileName} {
      allow read: if isOwner(userId);
      allow write: if isOwner(userId)
                   && request.resource.size < 10 * 1024 * 1024
                   && (isImage() || isPDF());
    }

    // Public app content
    match /content/{path=**} {
      allow read: if true;
      allow write: if false;
    }

    match /public/{path=**} {
      allow read: if true;
      allow write: if false;
    }
  }
}

```

