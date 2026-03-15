# Architecture Contract

Last updated: 2026-02-11

This document defines hard architectural constraints. Any exception requires explicit note in PR.

## 1. Layering

- `Views/` and `ContentView.swift` may depend on domain/store abstractions, never raw backend SDK calls.
- Domain models must not depend on UI frameworks.
- Networking/auth/storage integrations stay in dedicated modules.

## 2. State Management

- Single source of truth for checklist/profile state (`ContentStore`, `StudentProfileStore`).
- No duplicate mutable state copies for the same business entity.
- Derived state should be computed, not persisted redundantly.

## 3. File Structure Evolution Rules

- If a file exceeds ~800 LOC and contains multiple responsibilities, split it.
- New complex UI components go under `/arrival uk/Views/` as focused files.
- Shared security and utility logic must be centralized (e.g., backend `/src/utils`).

## 4. Dependency Direction

Allowed direction:

- View -> Store/Domain -> Integration

Disallowed:

- Integration -> View
- Data persistence -> UI rendering layer

## 5. Contracted Interfaces

- Security policy checks must be centralized and reusable.
- URL validation and trust enforcement remain centralized (`ExternalURLPolicy`, `SecureHTTPClient`).
- Keychain access only through `KeychainManager`.

## 6. Cross-Platform Contract

- Business data in JSON/content schema remains platform-agnostic.
- IDs and content fields are stable and deterministic.
- Platform-specific behavior stays at presentation/integration edges.

