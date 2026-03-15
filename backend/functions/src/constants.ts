export const Collections = {
  users: "users",
  admins: "admins",
  referrals: "referrals",
  devices: "devices",
  analytics: {
    root: "analytics",
    events: "events",
    items: "items",
  },
  support: {
    root: "support",
    tickets: "tickets",
    items: "items",
    messages: "messages",
  },
  ops: {
    root: "ops",
    userDeletionCleanupQueue: "userDeletionCleanupQueue",
    items: "items",
  },
  notifications: {
    root: "notifications",
    queue: "queue",
    pending: "pending",
  },
  content: {
    root: "content",
    tasks: "tasks",
    items: "items",
  },
} as const;

export const TaskTiming = {
  monthBeforeArrival: "month_before_arrival",
  weekBeforeArrival: "week_before_arrival",
  firstWeek: "first_week",
  firstMonth: "first_month",
  anytime: "anytime",
} as const;
