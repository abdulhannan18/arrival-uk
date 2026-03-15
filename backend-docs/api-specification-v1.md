# API Specification v1 (Contract Draft)

Last updated: 2026-02-10
Base URL: `https://api.yourapp.com/v1`
Auth: `Authorization: Bearer <firebase-id-token>`

## User
- `POST /auth/register`
- `GET /users/me`
- `PUT /users/me`
- `DELETE /users/me`

## Content
- `GET /content/categories`
- `GET /content/categories/{categoryId}`
- `GET /content/tasks/{taskId}`
- `GET /content/search?q=...&limit=...`

## Progress
- `GET /progress`
- `POST /progress/tasks/{taskId}/complete`
- `DELETE /progress/tasks/{taskId}/complete`

## Custom Tasks
- `GET /users/me/tasks`
- `POST /users/me/tasks`
- `PUT /users/me/tasks/{taskId}`
- `DELETE /users/me/tasks/{taskId}`

## Notifications
- `GET /notifications/settings`
- `PUT /notifications/settings`
- `POST /notifications/register-device`

## Analytics
- `POST /analytics/events`
- `GET /analytics/insights`

## Support
- `POST /support/tickets`
- `GET /support/tickets`
- `POST /support/tickets/{ticketId}/messages`

## Referrals
- `GET /referrals/me`
- `POST /referrals/claim`

## Premium
- `GET /premium/status`
- `POST /premium/purchase`

## Monetization Tracking
- `POST /monetization/ad-impression`
- `POST /monetization/affiliate-click`

## Partnerships
- `GET /partnerships/featured?category=...&limit=...`

## Error Envelope
```json
{
  "error": {
    "code": "invalid_request",
    "message": "Missing required field"
  }
}
```

## Status Codes
- `400` invalid request
- `401` unauthenticated/expired token
- `403` forbidden
- `404` not found
- `429` rate limited
- `500` internal error
