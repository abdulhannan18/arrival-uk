# Privacy Compliance Checklist

Last updated: 2026-02-11

Engineering checklist for privacy-by-design implementation.

## 1. Data Inventory

Track and review all collected data:

- Profile fields (name, university, city, course, study level, arrival date).
- Task completion/progress/custom tasks.
- Auth provider identifiers.
- Notification token and delivery metadata.
- Operational analytics events.

## 2. Data Minimization

- Collect only data required for app functionality.
- Avoid storing full PII in analytics where aggregate or derived value is sufficient.
- Apply retention windows where feasible (e.g., analytics event expiration marker).

## 3. User Rights Support

- Data deletion path must clear local and backend user data.
- Data export path should remain supported for profile + progress data.
- Consent-dependent features (ads/tracking) must respect user settings.

## 4. Disclosure Consistency

- App Store / Play Store privacy forms must match SDK behavior.
- If analytics/ads SDKs collect data, declarations must reflect it.
- Legal links in-app must be valid and production-ready.

## 5. Logging Restrictions

- No raw emails/phone numbers in logs unless strictly required and redacted.
- No auth tokens/session secrets in logs.

## 6. Release Privacy Gate

Before release:

1. Validate policy links and support email.
2. Confirm no new undeclared data collection.
3. Confirm delete/export flows still work.
4. Confirm consent toggles influence behavior as expected.

