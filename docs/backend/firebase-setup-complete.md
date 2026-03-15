# Firebase Setup (Complete, Production-Oriented)

Last updated: 2026-02-10

This extends the existing chunk-1 backend scaffold with environment strategy, hardened rules/indexes, functions config, monitoring, and backup controls.

## 1) Environment Model

Use three Firebase projects:

- `arrival-uk-dev`
- `arrival-uk-staging`
- `arrival-uk-prod`

CLI profile pattern:

```bash
firebase use --add
firebase use dev
firebase use staging
firebase use prod
```

Deploy safely:

```bash
# staging only
firebase deploy --project arrival-uk-staging

# production only
firebase deploy --project arrival-uk-prod
```

## 2) Required Firebase Services

- Authentication
- Firestore
- Cloud Functions
- Cloud Storage
- Firebase Hosting (optional admin web)
- Cloud Messaging (FCM)
- Analytics + Crashlytics
- App Distribution (for internal/beta)

## 3) Firestore Rules + Indexes

Source of truth in repo:

- `backend/firestore.rules`
- `backend/firestore.indexes.json`

Deploy:

```bash
cd backend
firebase deploy --only firestore:rules
firebase deploy --only firestore:indexes
```

## 4) Functions Runtime Configuration

Set secrets/config:

```bash
cd backend

firebase functions:config:set app.name="Arrival UK"
firebase functions:config:set app.url="https://arrivaluk.app"
firebase functions:config:set app.support_email="support@arrivaluk.app"

firebase functions:config:set sendgrid.api_key="SG_XXX"
firebase functions:config:set sendgrid.from_email="noreply@arrivaluk.app"

firebase functions:config:set twilio.account_sid="AC_XXX"
firebase functions:config:set twilio.auth_token="XXX"
firebase functions:config:set twilio.phone_number="+44XXXXXXXXXX"
```

View config:

```bash
firebase functions:config:get
```

## 5) Functions Build + Deploy

```bash
cd backend/functions
npm install
npm run build

cd ..
firebase deploy --only functions
```

## 6) Storage Rules

Source of truth in repo:

- `backend/storage.rules`

Deploy:

```bash
cd backend
firebase deploy --only storage
```

## 7) Monitoring and Alerts (Minimum)

Create Cloud Monitoring alerts for:

- Function error rate > 1%
- Function p95 latency > 10s
- Firestore read/write usage > 80%
- Storage usage > 80%
- DAU drop > 20% day-over-day

Operational channel:

- Slack/email for high-severity alerts
- Daily digest for medium severity

## 8) Backup and Recovery

Recommended retention:

- Daily backups: 7 days
- Weekly backups: 4 weeks
- Monthly backups: 12 months

Disaster recovery checklist:

- Restore Firestore export to staging first
- Validate schema + counts
- Roll forward only after verification

## 9) Cost Controls

Set billing budgets and automated alerts:

- 50%
- 75%
- 90%
- 100%

Optimization baseline:

- Cache read-heavy content in function memory/edge cache
- Minimize fan-out writes
- Use composite indexes only where query patterns require them

