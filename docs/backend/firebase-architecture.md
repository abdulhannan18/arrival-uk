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
