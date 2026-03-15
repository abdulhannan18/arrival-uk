# Arrival UK - Launch Readiness Checklist (Living)

Last Updated: 2026-02-09  
Owner: Product + Engineering

This is the operational version of your checklist with priority and current status.

## P0 (Blockers Before App Store Submission)

- [ ] `Privacy Policy URL` live and added to App Store Connect.
- [ ] `Terms of Service URL` live and linked in app.
- [ ] `App Privacy` answers in App Store Connect match actual SDK behavior (Google Sign-In / ads / analytics).
- [x] `Sign in with Apple` present whenever third-party auth is present.
- [~] `ATT` flow implemented if tracking-enabled SDK behavior is used (ads SDK currently optional).
- [~] `Crash reporting` integrated; validate in release-like build on real device.
- [x] `No secrets in app binary` (API keys/tokens not hardcoded).
- [x] `ATS enforced` (no arbitrary HTTP loads).
- [ ] `Accessibility minimums` validated (VoiceOver, Dynamic Type, contrast).
- [~] `Launch stability` proven by repeated simulator cold starts; device cold starts still need manual verification.

## P1 (Strongly Recommended Before External Beta)

- [~] `Structured logging` (CrashReporter + LaunchMetrics exist; verify release logging volume).
- [ ] `Unified error handling` with user-safe messages.
- [~] `Data export/delete` flow for privacy rights (local export + erase implemented; server-side deletion TBD).
- [x] `Support entrypoint` in app (support email + support center links in privacy sheet).
- [x] `In-app legal links` (Privacy, Terms, Ads disclosure).
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
- [x] CI pipeline present (`.github/workflows/ci.yml`) with iOS + backend gates.
- [x] Crash reporting integrated (CrashReporter forwards to Crashlytics when Firebase configured).

### Partially Done

- [~] ATS hardening present; final verification must include Info.plist/App Store privacy consistency review.
- [~] Auth flows present; full token lifecycle handling depends on backend/session rollout.
- [~] Crash reporting validated on real device Release build (requires Firebase project + GoogleService-Info.plist).

### Missing / Pending

- [ ] App-level structured logger for release-safe telemetry.
- [ ] Unified AppError/ErrorHandler wiring across all feature flows.
- [ ] ATT + consent UX finalized relative to monetization mode.
- [ ] Legal URLs and support workflows finalized in product settings UI.

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
