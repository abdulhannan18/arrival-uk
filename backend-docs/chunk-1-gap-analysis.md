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
