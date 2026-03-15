# Backend Scaffold

This directory contains Firebase-oriented backend scaffolding for architecture rollout.

## Structure
- `backend/functions`: Cloud Functions source (TypeScript)
- `backend/firestore.rules`: Firestore security rules
- `backend/firestore.indexes.json`: Firestore indexes
- `backend/storage.rules`: Cloud Storage security rules
- `backend/firebase.json`: Firebase deployment config

## Quick Start
1. `cd backend/functions`
2. `npm install`
3. `npm run build`
4. from `backend/`: `firebase emulators:start`

## Notes
- This scaffold is intentionally non-invasive to current iOS runtime.
- iOS integration should be enabled in a separate pass after Firebase Auth/Firestore packages are added to Xcode target.
- Email/SMS functions are scaffolded with graceful fallback if provider secrets/dependencies are not yet configured.
