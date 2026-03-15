# Firestore Data Model (v1)

Last updated: 2026-02-10

## Collections Overview
- `/users/{userId}`
- `/users/{userId}/customTasks/{taskId}`
- `/users/{userId}/progress/{taskId}`
- `/content/categories/{categoryId}`
- `/content/tasks/{taskId}`
- `/analytics/events/{eventId}`
- `/monetization/adImpressions/{impressionId}`
- `/monetization/affiliateClicks/{clickId}`
- `/support/tickets/{ticketId}` and `/support/tickets/{ticketId}/messages/{messageId}`
- `/referrals/{referralCode}`
- `/notifications/queue/{notificationId}`
- `/config/featureFlags`
- `/analytics/daily/{yyyy-mm-dd}`

## User Document Shape
```json
{
  "userId": "uid",
  "email": "student@example.com",
  "displayName": "Student Name",
  "authProvider": "google",
  "profile": {
    "university": "University of Oxford",
    "course": "Computer Science",
    "studyLevel": "undergraduate",
    "city": "Oxford",
    "arrivalDate": "2026-09-15T00:00:00Z",
    "nationality": "IN"
  },
  "preferences": {
    "language": "en",
    "notifications": {
      "taskReminders": true,
      "weeklyDigest": true,
      "productUpdates": false
    },
    "privacy": {
      "allowAnalytics": true,
      "allowPersonalizedAds": true,
      "dataSharing": false
    }
  },
  "progress": {
    "completedTasks": ["task-1"],
    "totalTasks": 50,
    "completionRate": 0.02,
    "lastActivityDate": "timestamp"
  },
  "engagement": {
    "loginCount": 4,
    "referralCode": "ABCD12"
  },
  "monetization": {
    "isPremium": false,
    "premiumExpiryDate": null,
    "lifetimeValue": 0
  },
  "metadata": {
    "createdAt": "timestamp",
    "updatedAt": "timestamp",
    "version": 1,
    "platform": "ios",
    "appVersion": "1.0.0"
  }
}
```

## Content Documents
- `categories` stores card-level metadata (title/icon/order/visibility).
- `tasks` stores canonical task payload and rendering content sections.
- Use `isPublished` + `version` for staged rollouts.
- Optional filters per task:
  - `universityFilters`
  - `countryFilters`
  - `studyLevelFilters`

## Index Strategy
Create indexes for:
1. users by `metadata.createdAt desc`
2. users by `profile.university asc`
3. tasks by `categoryId asc, order asc, isPublished asc`
4. events by `userId asc, eventType asc, timestamp desc`

## Rules Baseline
- User can read/write only their own profile and nested user data.
- Public read on `/content/**`.
- Admin-only writes on `/content/**`.
- `/analytics/**` write-only from authenticated users.

## Versioning
- Keep `metadata.version` on user docs.
- Keep `version` on content docs.
- Add migration handlers in Cloud Functions for schema bumps.
