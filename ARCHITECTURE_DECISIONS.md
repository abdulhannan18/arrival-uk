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
