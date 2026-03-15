# Arrival UK Engineering Playbook

Last updated: 2026-02-11
Owner: Engineering

This playbook is the operating system for code quality. We do not rely on memory. We rely on these standards + CI gates.

## 1. Quality Principles

- Security-first: fail closed on auth, secrets, and untrusted input.
- Architecture before velocity: no cross-layer shortcuts.
- Stable delivery: every merge is releasable.
- Observability: errors are diagnosable in production.
- Backward compatibility: no silent data loss or schema breaks.

## 2. Architecture Boundaries (mandatory)

- UI layer (`/arrival uk/Views`, `ContentView.swift`): rendering, interaction wiring only.
- Domain layer (`/arrival uk/Models.swift`, view state logic): pure business rules.
- Data layer (`/arrival uk/ContentData.swift`, repositories/stores): persistence and data transformation.
- Integration layer (`/arrival uk/Networking`, `/arrival uk/Auth`, backend functions): external systems.

Forbidden:
- UI directly calling Firebase/network primitives.
- Integration code embedding UI concerns.
- Business logic hidden in ad-hoc view modifiers.

## 3. Definition Of Done (DoD)

A change is done only when all are true:

1. Build + analyze pass for iOS target.
2. Backend lint/build/tests pass (if backend touched).
3. Security checks pass (`Scripts/quality_gate.sh`).
4. No new warnings/errors in modified files.
5. Architecture boundaries remain intact.
6. Documentation updated when behavior/contracts change.
7. Release gates still green (`RELEASE_GATES.md`).

## 4. Change Types And Required Checks

### Feature change
- Unit/integration tests for new logic.
- Error states + fallback behavior.
- Performance impact check (launch/scroll/memory sensitive paths).

### Security change
- Threat model note in PR.
- Negative tests (blocked path) added.
- No degraded authz/authn guarantees.

### UX/design change
- Dynamic Type + accessibility labels checked.
- Device matrix sanity pass (small + large phones).

### Data/schema change
- Migration safety or fallback path documented.
- No orphaned state; no silent reset unless intentional.

## 5. Branch and Merge Discipline

- Small, focused PRs (<500 logical LOC preferred).
- One concern per PR whenever possible.
- PR must reference affected gate(s) from `RELEASE_GATES.md`.

## 6. Code Limits (enforced by script)

- No `TODO`/`FIXME` in shipping paths.
- No insecure `http://` usage in production source.
- No hardcoded secrets/tokens.
- Maximum Swift file length soft limit: 1200 LOC (exceptions must be justified).

## 7. Incident and Rollback

- Every release must have rollback path.
- P0 incident response starts immediately; feature work pauses.
- Root cause + prevention action added to backlog within 24h.

## 8. Cross-Platform Readiness Rules

- Keep domain models and content schema platform-neutral.
- Avoid iOS-specific assumptions in business rules.
- Prefer data-driven behavior over hardcoded UI branching.

