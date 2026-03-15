# Arrival UK - Baseline (Code + Goals)

## 1) Project Location and Directory Issue

- Canonical project path: `/Users/abdulhannan/Documents/Projects/Arrival UK`
- Older duplicate and alias paths were removed during cleanup.
- Current state: one clean working repo remains in the Finder location above.

## 2) Current Code Inventory

### Main app files
- `arrival uk/arrival_ukApp.swift`
- `arrival uk/ContentView.swift`
- `arrival uk/Data/content.json`

### Project config and assets
- `arrival uk.xcodeproj/project.pbxproj`
- `arrival uk/Assets.xcassets/Contents.json`

### What is implemented now
- SwiftUI single-screen checklist app with:
- Header, progress section, journey strip, category cards, and "Add Personal Task".
- Categories:
- Before Arrival
- Health & Admin
- Money & Banking
- Travel & Discounts
- Add-task sheet and task completion toggles.
- Task details sheet with timing/priority badges and optional source link button.
- Haptic feedback on completion (guarded for low power mode).
- Theme system with light/dark support.
- Content loading from bundled JSON (`content.json`) with fallback to sample data.
- Starter task dataset seeded in `content.json` (pre-arrival, admin, banking, travel).
- Ad policy engine wired to app events (warm-up, interaction threshold, cooldown, hourly/session caps).
- Ad & Privacy settings screen implemented (personalization toggle, tracking status, policy link).
- Consent state persisted locally and synchronized with runtime ad request mode.
- Category safety filters implemented in-app (blocked sensitive categories are rejected before request).

## 3) Performance Work Already Applied

- Replaced standard stacks with lazy rendering (`LazyVStack`) for better scaling.
- Deferred optional visual effects until after first frame to reduce launch work.
- Simplified progress fill rendering to avoid unnecessary layout cost.
- Reused haptic generator instead of creating one on every tap.
- Added aggregate stats structs to avoid repeated full-array recalculations.
- Added startup telemetry markers (debug logging) for init, content load, and first-frame effects.
- Added conservative rendering mode for low-memory or Low Power Mode devices.
- Added in-memory payload cache and memory-mapped JSON read path for bundled content.

## 4) Build and Runtime Status

- Command-line simulator build currently succeeds:
- `xcodebuild -project "arrival uk.xcodeproj" -scheme "arrival uk" -destination "generic/platform=iOS Simulator" -derivedDataPath /tmp/arrivaluk-derived CODE_SIGNING_ALLOWED=NO build`
- `content.json` is confirmed copied into app bundle at build output.
- Earlier `UUID` vs `String` ID mismatch was resolved in `AddTaskSheet`.

## 5) Product Goals Agreed So Far

- Core purpose: guide international students with UK setup steps from pre-arrival to early settle-in.
- Quality bar: no compromise on speed, smoothness, functionality, and clean premium UI.
- Platform: iOS first (17+), Android later with portable content architecture.
- UX tone: professional, serious, friendly, uncluttered, high trust.
- Monetization for initial launch: ads only, no affiliate links.
- Ad policy: delayed after warm-up, non-disruptive, no gambling/sensitive categories.
- Data quality: official references required for critical tasks.

## 6) Open Decisions

- Final app name and final icon system.
- Final typography and color token lock.
- Exact ad format and placement timing rules.
- Full category/task dataset and sequencing.
- Reminder cadence and iCloud sync timing.

## 7) What I Need From You to Build the Real Version

### Content inputs
- Full task list per category (title + short description).
- For each task: best timing window (for example, "2-4 weeks before arrival").
- Official source link for each task (gov/NHS/university/bank/transport).
- Priority level per task: must-do, should-do, optional.

### Product decisions
- Final app name.
- Final icon direction choice (playful-premium midpoint).
- Confirm first release ad policy:
- first ad delay (minutes),
- max frequency,
- allowed categories only.

### UX decisions
- Final color direction (2 to 3 brand colors).
- Typography choice.
- Reminder behavior (off by default or soft opt-in).

## 8) Next Build Steps (After Your Inputs)

1. Replace seeded starter tasks with your final verified dataset from official sources.
2. Add startup telemetry and app-launch tuning for older iPhones.
3. Add Google Mobile Ads package in Xcode so the conditional `GoogleMobileAds` client is activated in builds.
4. Lock visual system and icon set.
5. Prepare App Store release checklist.
