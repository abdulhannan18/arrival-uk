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

