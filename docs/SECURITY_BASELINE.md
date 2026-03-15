# Security Baseline

Last updated: 2026-02-11

This baseline is mandatory for all releases.

## 1. Authentication and Authorization

- Server-side authz decisions only; never trust client claims.
- Admin privileges must be resolved from authoritative storage (`admins/{uid}`), with fail-closed behavior.
- Privileged operation handlers must include explicit auth checks.

## 2. Data Protection

- Sensitive tokens/secrets only in iOS Keychain (`KeychainManager`).
- UserDefaults is allowed for non-sensitive state only.
- Any token persisted must support expiration/rotation policy.

## 3. Input/Output Hardening

- Escape/sanitize all user-supplied content before rendering in HTML/email.
- Validate URLs and enforce HTTPS for external navigation/network requests.
- Reject invalid formats early with typed errors.

## 4. API and Transport

- HTTPS only.
- Certificate trust policy enforced in `SecureHTTPClient`.
- Pinning policy configured by environment with explicit allow-listing.
- Firebase SDK traffic (`*.cloudfunctions.net`, `*.firebaseio.com`) does not use `SecureHTTPClient`,
  so certificate pinning is not applied there by design. Compensating controls are mandatory:
  App Check enforcement + Firebase Security Rules.

## 5. Abuse Resistance

- Rate limits must be atomic and transaction-safe.
- Privileged communication endpoints must be rate-limited.
- Large fan-out operations use bounded concurrency and error handling.

## 6. Secrets Handling

- No API secrets in source code.
- Cloud Functions secrets must come from Secret Manager (`functions.runWith({ secrets: [...] })`).
- Do not store credentials in Firebase Runtime Config (`functions.config()`).
- Logs must not include raw PII, credentials, or full tokens.

## 7. Security CI Checks

Required per merge:

- `npm audit --omit=dev`
- `Scripts/quality_gate.sh`
- backend lint/build/tests
- CodeQL workflow pass (`Analyze backend/functions`)

## 8. Branch Protection

- Main branch must require pull request + at least one approval.
- Main branch must block force-push and deletion.
- Main branch must require passing status checks from CI + CodeQL.
- Main branch must disallow direct commits by default.

## 9. Incident Policy

- P0/P1 vulnerabilities block release.
- Fix + regression test required for every security incident.
