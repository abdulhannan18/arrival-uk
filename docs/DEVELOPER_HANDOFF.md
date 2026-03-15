# Arrival UK - Developer Handoff Note

Last updated: 2026-02-09
Owner context: iOS SwiftUI app, Android considered in future via feature/design parity (not shared Swift UI code).

## 1. Current Product Snapshot
- App type: iOS SwiftUI checklist app for international students moving to the UK.
- Core UX: Home categories -> category detail -> task detail -> official guidance links.
- Runtime status: builds and launches successfully on simulator and iOS target.
- Content source of truth: bundled JSON in `arrival uk/Data/content.json` and `arrival uk/Data/categories.json`.
- Current bundled data: 5 categories in both files, with richer tasks in `content.json`.

## 2. Codebase Structure (What Lives Where)
- `arrival uk/arrival_ukApp.swift`
  - App entry point.
- `arrival uk/ContentView.swift`
  - Main feature shell and almost all UI composition.
  - Home screen, category cards, detail overlay, modal system, profile sheet wiring, task sheet wiring, help/privacy sheets.
- `arrival uk/ContentData.swift`
  - ContentStore, bundle loading, payload merge/sanitize/normalize, validation and fallback helpers.
  - Progress persistence and restoration.
- `arrival uk/Models.swift`
  - All task/category/content section models and sample data.
- `arrival uk/DesignSystem.swift`
  - Theme tokens, spacing, motion, haptics, performance profile, layer z-index, modifiers.
- `arrival uk/StudentProfile.swift`
  - Student profile store, Apple/Google auth state model, persistence.
- `arrival uk/AdSystem.swift`
  - Ad policy/consent/runtime abstraction and coordinator.
- `Scripts/validate_content.swift`
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
- File: `arrival uk/ContentData.swift`
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
- File: `arrival uk/ContentData.swift`
- Key area: `loadFromBundle()` and new `decodeProgressSnapshot(storageKey:)`.
- Change:
  - Bundle resolution and persisted snapshot decode occur in background queue.
  - Snapshot is cached and then applied on main actor.
- Outcome:
  - Lower risk of startup hitch/jank.

### 4.3 Profile save hardened for auth provider correctness
- File: `arrival uk/ContentView.swift`
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
Run from the project root.

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
  - Added `arrival uk/Security/ExternalURLPolicy.swift`.
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
  - Added `arrival uk/Auth/AuthStateValidator.swift`.
  - Persisted profile auth snapshot is normalized on load to repair invalid provider/id combinations.
- Secure sign-out path added:
  - Added `arrival uk/Security/KeychainManager.swift`.
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
These are the remaining launch-facing items that still require attention:

- Validate legal URLs are live and correct:
  - Values are configured in `arrival uk/Core/AppConfig.swift` (`AppConfig.legal`).
  - Ensure `https://arrivaluk.app/privacy`, `/terms`, `/support`, `/delete-data` are live before TestFlight/App Store submission.
- Validate crash reporting end-to-end (release-like build):
  - Runtime wiring exists in `arrival uk/Core/CrashReporter.swift` and app bootstrap.
  - dSYM upload script exists via `Scripts/crashlytics_run.sh` build phase.
  - Still requires a real device Release build validation in Firebase Crashlytics console.
- Add explicit data export flow (GDPR/UK GDPR readiness):
  - Data deletion is exposed as a link; export is not yet implemented.
- Add automated UI test coverage for critical flows:
  - Auth handoff (Apple/Google), external link opening policy, and sign-out flows.

### Recommended next execution order
1. Validate legal URLs are live + do a final in-app link check.
2. Validate Crashlytics on a real device Release build.
3. Implement data export + strengthen account/data deletion (backend + local).
4. Add UI tests for the launch-critical user flows.
