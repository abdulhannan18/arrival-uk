# Backend Scaffold

This directory contains Firebase-oriented backend scaffolding for architecture rollout.

## Structure
- `/Users/abdulhannan/Desktop/arrival uk/backend/functions`: Cloud Functions source (TypeScript)
- `/Users/abdulhannan/Desktop/arrival uk/backend/firestore.rules`: Firestore security rules
- `/Users/abdulhannan/Desktop/arrival uk/backend/firestore.indexes.json`: Firestore indexes
- `/Users/abdulhannan/Desktop/arrival uk/backend/storage.rules`: Cloud Storage security rules
- `/Users/abdulhannan/Desktop/arrival uk/backend/firebase.json`: Firebase deployment config

## Quick Start
1. `cd /Users/abdulhannan/Desktop/arrival uk/backend/functions`
2. `npm install`
3. `npm run build`
4. from `/Users/abdulhannan/Desktop/arrival uk/backend`: `firebase emulators:start`

## Notes
- This scaffold is intentionally non-invasive to current iOS runtime.
- iOS integration should be enabled in a separate pass after Firebase Auth/Firestore packages are added to Xcode target.
- Email/SMS functions are scaffolded with graceful fallback if provider secrets/dependencies are not yet configured.
