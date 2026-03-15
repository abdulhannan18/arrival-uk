# Codebase Map

- Finder location: `/Users/abdulhannan/Documents/Projects/Arrival UK`
- Repo root: `.`
- Full dump generator: `bash Scripts/build_codebase_dump.sh` (writes `docs/generated/CODEBASE_DUMP.md`)
- Line count script: `bash Scripts/line_counts.sh`

## Top-Level
- .git
- .github
- AppConfig
- ArrivalWidgetExtension
- docs
- Scripts
- arrival uk
- arrival uk.xcodeproj
- arrival ukTests
- backend

## Notable Components

### iOS App (SwiftUI)
- App entry: `arrival uk/arrival_ukApp.swift`
- Home coordinator: `arrival uk/ContentView.swift` + extracted views in `arrival uk/Views/`
- Content system: `arrival uk/ContentData.swift`, `arrival uk/ContentPayloadValidator.swift`
- Models: `arrival uk/TaskContentModels.swift` + supporting types in `arrival uk/Models.swift`
- Security: `arrival uk/Security/KeychainManager.swift`, `arrival uk/Security/EncryptedDefaultsStore.swift`, `arrival uk/Security/ExternalURLPolicy.swift`
- Networking: `arrival uk/Networking/SecureHTTPClient.swift`
- Auth scaffolding: `arrival uk/Auth/AuthenticationManager.swift`, `arrival uk/Auth/GoogleSignInBridge.swift`
- Ads scaffolding: `arrival uk/AdSystem.swift`

### Backend (Firebase Cloud Functions)
- Entry: `backend/functions/src/index.ts`
- Auth lifecycle + GDPR cleanup: `backend/functions/src/auth.ts`
- Email: `backend/functions/src/email.ts`
- Notifications: `backend/functions/src/notifications.ts`
- SMS: `backend/functions/src/sms.ts`
- Shared security utils: `backend/functions/src/utils/*`

### Rules / Ops
- Firestore rules: `backend/firestore.rules`
- Storage rules: `backend/storage.rules`
- CI: `.github/workflows/ci.yml`
- Release gates: `Scripts/release_gate_check.sh`, `Scripts/strict_smoke.sh`

### Docs Layout
- General project docs: `docs/*.md`
- Reports: `docs/reports/*`
- Backend planning docs: `docs/backend/*`
- Generated dump output: `docs/generated/CODEBASE_DUMP.md` (not tracked)

## Full File List
- To list every tracked file: `git ls-files`
