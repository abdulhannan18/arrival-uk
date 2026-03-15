# Arrival UK Phase 8: Android Parity Blueprint

## Scope
This document defines the iOS-to-Android parity contract for Phase 8 so the core Arrival UK behavior stays identical across SwiftUI and Jetpack Compose.

## 1) Universal Token Contract
Use an 8px base unit in design tooling and code generation.

- Base grid unit: `8`
- iOS spacing source: `AppTheme.Spacing` in `arrival uk/AppSpacing.swift`
- Android mapping rule: `1 iOS spacing token step == same numeric dp value` on Compose

Token mapping:

| Token | iOS value | Android value |
|---|---:|---:|
| `xs` | 4pt | 4dp |
| `sm` | 8pt | 8dp |
| `md` | 16pt | 16dp |
| `lg` | 24pt | 24dp |
| `xl` | 32pt | 32dp |
| `xxl` | 40pt | 40dp |

Color mapping:

- iOS semantic colors: `bgPrimary`, `bgSurface`, `textPrimary`, `textSecondary`, `actionPrimary`, `statusUrgent`
- Android: map to `MaterialTheme.colorScheme` extension values with same semantic names.

## 2) Component Mapping (iOS -> Compose)

| iOS component | Android Compose target | Notes |
|---|---|---|
| `CopilotHeaderView` | `CopilotHeader` composable | Respect status bar insets using `WindowInsets.statusBars` |
| `SwipeableHeroStack` | `SwipeableHeroStack` composable | Same commit threshold `150` and rotation factor |
| `MaintenanceTaskRow` | `MaintenanceTaskRow` composable | Keep lower visual weight than hero card |
| `SecureDocumentWalletSection` + `DocumentFanView` | `SecureWalletSection` + fan stack composable | Keep card ratio `1.586:1` and `12°` fan delta |
| `TaskDetailSheetView` Safari half sheet | `ModalBottomSheet` + `CustomTabsIntent` | Use 50% and full-screen detents |
| `ConfettiOverlay` (`CAEmitterLayer`) | Compose canvas/particle emitter | Trigger on settled transition only |

Animation mapping:

- iOS spring (`response ~0.45`, `damping ~0.8`) -> Compose spring with low-medium stiffness and damping ratio near `0.8`.
- iOS interactive swipe snapback -> Compose `animate*AsState` with spring.

## 3) Domain Logic Contract (KMP-ready)

Single source of truth for task prioritization:

- iOS domain file: `arrival uk/Core/TaskPriorityDomain.swift`
- `TaskEngine` is now thin state wiring and contains no SwiftUI animation logic.
- Contract methods:
  - `partitionAndSort(from:isSettledMode:)`
  - `nextTasks(from:limit:isSettledMode:)`
  - `nextTasks(fromQueues:maintenance:limit:)`

Required parity rule:

- Android implementation must produce identical top-task ordering for same input payload.

## 4) Safe Area / Insets Contract

- Header: pass runtime top inset into `CopilotHeaderView` (`topSafeAreaInset`) and adjust top padding dynamically.
- Bottom surfaces: include runtime bottom inset in content spacing and sticky bars.
- Android equivalent:
  - Use `WindowInsets.statusBars` for header top spacing.
  - Use `WindowInsets.navigationBars` for bottom spacing.

## 5) UK Localization Contract

- Shared formatting source: `arrival uk/Core/UKLocaleFormat.swift`
- Date output: UK medium style (`en_GB`), e.g. `2 Mar 2026`
- Currency output: GBP (`£`) regardless of device locale.

Android equivalent:

- Dates: `DateTimeFormatter.ofLocalizedDate(FormatStyle.MEDIUM).withLocale(Locale.UK)`
- Currency: `NumberFormat.getCurrencyInstance(Locale.UK)` with GBP code.

## 6) Asset Rule

- Keep iconography vector-only (SF Symbols on iOS, Material Symbols/vector assets on Android).
- Raster assets are disallowed for scalable iconography.
- Current audit command found no `png/jpg/jpeg/webp` assets in app sources.

Audit command used:

```sh
find 'arrival uk' -type f | rg '\.(png|jpg|jpeg|webp)$'
```

## 7) Verification Checklist

- [ ] Token names and values mapped into Android `Theme.kt`
- [ ] Domain ordering parity tests passing on iOS and Android
- [ ] Header + bottom inset parity validated on tall aspect ratios (e.g., 21:9)
- [ ] UK date and GBP currency formatting parity validated on both platforms
