# Storage & CDN Architecture

Last updated: 2026-02-10

## 1) Bucket Layout

Use stable, predictable paths:

```text
gs://<bucket>/
  users/
    {userId}/
      profile/
      documents/
      uploads/
  content/
    categories/
    tasks/
    partners/
  public/
    app-icons/
    illustrations/
    guides/
  backups/
    firestore/
```

## 2) Security Model

Principles:

- Public read only for curated `content/` and `public/`.
- User-owned write/read for `users/{userId}/...`.
- Validate content type and max size in Storage rules.

Rules file:

- `backend/storage.rules`

## 3) Processing Pipeline

Cloud Functions hooks:

- On upload in `users/{userId}/profile/*`
  - normalize metadata
  - optional resize/thumb pipeline
- On user delete
  - remove `users/{userId}/` files

Code scaffold:

- `backend/functions/src/storage.ts`

## 4) CDN & Caching

For public assets:

- aggressive immutable cache for versioned files
- short cache for dynamic manifests

Recommended headers:

- Images/static assets: `public, max-age=31536000, immutable`
- Dynamic JSON: `public, max-age=300`

## 5) iOS Client Guidance

Use async upload/download wrappers with:

- auth check before upload
- strict file-size and MIME validation
- metadata tags (`uploadedBy`, `uploadedAt`, `documentType`)

Implementation target:

- `arrival uk/Features/Storage/StorageManager.swift` (when enabled)

