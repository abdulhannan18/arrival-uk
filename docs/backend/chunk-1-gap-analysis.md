# Chunk 1 Gap Analysis (Applied Against Current Codebase)

Last updated: 2026-02-10

## Already Implemented (no duplicate changes made)
- Keychain storage utility:
  - `arrival uk/Security/KeychainManager.swift`
- Secure logout path + progress clear:
  - `arrival uk/StudentProfile.swift`
- URL allow-list policy:
  - `arrival uk/Security/ExternalURLPolicy.swift`
- HTTPS-enforced HTTP client:
  - `arrival uk/Networking/SecureHTTPClient.swift`
- Auth state validation:
  - `arrival uk/Auth/AuthStateValidator.swift`
- Task search and reminders:
  - `arrival uk/Features/Search/TaskSearchSheet.swift`
  - `arrival uk/Features/Notifications/NotificationManager.swift`
- Crash reporting bootstrap:
  - `arrival uk/Core/CrashReporter.swift`

## Added in this chunk (net-new)
- Backend architecture document:
  - `docs/backend/firebase-architecture.md`
- Firestore data model and index plan:
  - `docs/backend/firestore-data-model.md`
- REST API v1 contract draft:
  - `docs/backend/api-specification-v1.md`
- Cloud Functions scaffold for auth lifecycle:
  - `backend/functions/auth.ts`
  - `backend/functions/package.json`
  - `backend/functions/tsconfig.json`

## Deferred to later chunks
- Wiring FirebaseAuth/Firestore/Functions runtime into iOS target.
- Firestore rules/index deployment automation.
- CI/CD workflows and environment provisioning.
