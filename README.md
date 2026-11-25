# Physical Therapy Clinic Manager

A Flutter mobile application for managing a physiotherapy clinic's daily operations — patient records, treatment sessions, treatment packages, debt tracking, home-visit route planning, and financial analytics — backed by Firebase.

## Overview

This app helps physical therapy practitioners manage their clinic from their phone: keeping patient records, scheduling and logging treatment sessions, tracking debts and package plans, viewing home-visit route maps, and reviewing cash-basis financial reports — all synced in real time through Firebase.

The application supports **multi-account architecture**, where each practitioner securely owns their scoped workspace under Firebase Authentication and Cloud Firestore.

## Features

- **Multi-Account & Secure Auth** — Email/password login and account creation with per-user data isolation (`users/{uid}/...`).
- **Doctor Display Name** — Optional doctor display name managed directly from Settings and reflected reactively in dashboard greetings.
- **Patient Management** — Add, edit, and view patient records (name, contact info, medical notes, treatment package, optional location).
- **Session Tracking & Scheduling** — Log and manage treatment sessions per patient with conflict prevention, duration, and auto-status detection.
- **Calendar & Schedule View** — Daily timeline view with overlapping cluster layout and weekly summary view.
- **Treatment Plans & Packages** — Track package progress, used sessions, and low-package remaining alerts.
- **Debt Tracking & Repayments** — Track patient debt balances, record partial or full debt payments, and view outstanding debtor lists.
- **Home-Visit Route Map** — Visual map of today's home visits powered by OpenStreetMap (`flutter_map`) with stop numbers, polyline route, and one-tap Google Maps turn-by-turn navigation.
- **Reminders & WhatsApp Integration** — Quick WhatsApp messaging with Egyptian phone number normalization and local scheduled notification reminders 30 minutes before sessions.
- **Financial Analytics & Charts** — Cash-basis income calculation, monthly income bar chart, and daily completed sessions trend line chart (`fl_chart`).
- **Light & Dark Theme** — Full RTL Arabic design system with Cairo / IBM Plex Sans Arabic typography.

## Tech Stack

- **Flutter** & **Dart**
- **Firebase Authentication** — Multi-account email/password auth with user profile management
- **Cloud Firestore** — Scoped real-time collections per user (`users/{uid}/...`)
- **Provider** — State management with scoped providers per authenticated session
- **flutter_map & latlong2** — OpenStreetMap rendering for home visits
- **fl_chart** — Financial and session trend charts
- **flutter_local_notifications & timezone** — Local notification scheduling with exact/inexact alarms
- **url_launcher & intl** — WhatsApp quick actions, phone dialer, and Arabic localization

## Architecture & Data Structure

The project follows a clean feature-based architecture:

```
lib/
    app/             # App root widget (PhysioApp), routes, AuthGate
    core/            # Theme, constants, shared services, and pure calculators
    features/        # Screens grouped by feature (auth, dashboard, patients, sessions, schedule, debts, route, reports, settings)
    models/          # Immutable data models (PatientModel, SessionModel, DebtPaymentModel)
    providers/       # State management (PatientProvider, SessionProvider, DebtProvider, ThemeProvider)
    repositories/    # Scoped Firestore data access layer
    widgets/         # Shared reusable UI widgets
```

### Firestore Scoped Data Hierarchy

All data is strictly scoped per authenticated practitioner:

```
users/{uid}/
    patients/{patientId}
    sessions/{sessionId}
    debtPayments/{paymentId}
    meta/migration
```

Legacy flat `patients/` collections are automatically migrated on initial login for the legacy owner (`kLegacyOwnerUid`) via `MigrationService`.

### Authentication Flow & Provider Scope

`PhysioApp` configures `MaterialApp.builder` to mount the authenticated `MultiProvider` (`PatientProvider`, `SessionProvider`, `DebtProvider`, keyed by `ValueKey(user.uid)`) above the navigator whenever a user is signed in:
- **Signed out** → Shows `LoginScreen` (supports login and account creation).
- **Signed in (Legacy Owner)** → Verifies migration status; shows `MigrationScreen` if unmigrated, then continues to `DashboardView`.
- **Signed in (Practitioner)** → Mounts scoped providers and renders `DashboardView`.
- **Signed out from Settings** → Cancels all scheduled notifications, signs out from Firebase, and unmounts providers.

### Doctor Display Name

Practitioners can configure their name from **الإعدادات > الحساب > الاسم**:
- Updates `FirebaseAuth.instance.currentUser.updateDisplayName(...)`.
- `FirebaseAuth.instance.userChanges()` triggers immediate reactive updates in Settings and the Dashboard greeting (`مرحباً بك دكتور {name}`).

## Getting Started

1. Clone the repository:
   ```bash
   git clone https://github.com/omarAhmed7525/Physical-Therapy-App.git
   ```
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Deploy Firestore rules and indexes:
   ```bash
   firebase deploy --only firestore:rules
   firebase deploy --only firestore:indexes
   ```
4. Run the project:
   ```bash
   flutter run
   ```

## Changes in `feature/improvements-2`

### S1 — Auth State Diagnostics

Temporary `[AUTHDIAG]` debug logs added in `main.dart` to diagnose the "login asked again after swipe from recents" report:
- Logs `FirebaseAuth.instance.currentUser?.uid` immediately after `Firebase.initializeApp()`.
- Subscribes to `authStateChanges()` and `idTokenChanges()` once and logs every event.
- Read logs on a physical device: `adb logcat | findstr AUTHDIAG`

> **Note:** These logs are `debugPrint` calls and are stripped in release builds. Remove before final release.

### S2 — Keyboard Unfocus on Route Transitions

Added a `RouteObserver`-based `FocusManager.instance.primaryFocus?.unfocus()` call on `didPush`, `didPop`, `didReplace`, and before each form pop to prevent lingering keyboard overlays when navigating between screens. This is a mitigation; if a blank white screen persists, try `flutter run --no-enable-impeller`.

### S3 — Overpayment Debt Offset Fix

**Root cause:** `DebtCalculator` summed `Σ remainingAmount` across sessions, which never went below zero per session. An overpayment on one session did not reduce the debt of a prior session.
**Fix:** Formula changed to `Σ max(0, price - paidAmount)` per session, then the global floor is applied — overpayments on later sessions now offset outstanding debt from earlier sessions.

### S4 — Manual Duration Field

Replaced the fixed dropdown (30/45/60/90 min) with a `DurationField` widget that includes quick-select chips (30, 45, 60, 90, 120 min) **and** manual +/− steppers. Users can now enter any integer duration in minutes.

### S5 — Configurable Commission Session Target

Each patient now has an integer `commissionSessionsTarget` field (default: 3, stored in Firestore). This sets how many completed sessions trigger a commission payout cycle. Existing patients are unaffected (the field defaults to 3 on `fromMap` when missing).

### S6 — End-Treatment Workflow and Patient Filtering

- Patients can be marked as **انتهى العلاج** (treatment ended) with a two-step confirmation. The action records `treatmentEnded: true` and `treatmentEndedAt` in Firestore.
- Two-step permanent delete with explicit warning dialog.
- Filter chips in `PatientsView` to show: **الكل / جارٍ / انتهى** (all / active / ended).
- Existing patients: `treatmentEnded` defaults to `false`, `treatmentEndedAt` defaults to `null` — no data loss.

### S7a — OpenStreetMap Location Picker

Replaced manual latitude/longitude text fields with an interactive `flutter_map` picker. When editing a patient's address:
- Tap the map to drop a pin and auto-fill coordinates.
- Use the **تحديد موقعي الحالي** button to request GPS location (`geolocator` 14.0.1).
- Required Android permissions declared in `AndroidManifest.xml` (`ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`).

### S7b — Google Maps URL Parser

`MapsUrlParser` (pure Dart, fully unit-tested) resolves a Google Maps share URL or short-link (`maps.app.goo.gl`) to `LatLng`:
- Parses `@lat,lng`, `q=lat,lng`, `ll=lat,lng`, `query=lat,lng`, and `!3dLAT!4dLNG` pin formats.
- Follows HTTP redirects from short-links via `http` package.

### S8 — Fisio Color Palette

All color tokens in `AppColors` updated to a physiotherapy-themed palette:
- Light: `primary` (#2F7D6E teal), `secondary` (#5DB39C mint), `background` (#F5F9F8), `surface` (#FFFFFF), `lightCard` (#EDF5F3).
- Dark: `darkPrimary` (#4CA896), `darkSecondary` (#7DCABB), `darkBackground` (#0F1E1C), `darkSurface` (#1A2E2B), `darkCard` (#213530).
- Semantic: `lightSuccess`/`darkSuccess`, `lightWarning`/`darkWarning`, `lightError`/`darkError`, `lightBorder`/`darkBorder`.

### S9 — GradientCard Widget

New shared widget `lib/widgets/gradient_card.dart`:
- `LinearGradient`: `topLeft → bottomRight`, start = card surface, end = `Color.alphaBlend(secondary × 0.20, surface)`.
- Border radius 16, `Clip.antiAlias`, transparent `Material` + `InkWell` for ripple.
- Optional `borderColor`/`borderWidth` overrides (used for today-highlight in Schedule weekly view).
- **No `BoxShadow` anywhere** — verified with `Get-ChildItem lib -Recurse | Select-String "BoxShadow"`.
- **`LinearGradient` only in `gradient_card.dart`** — verified similarly.
- Applied to: dashboard grid tiles, today session cards, patient cards, session cards, debtor rows, route list items, patient detail cards, reports metric cards, commission history rows, charts cards, and schedule weekly-view day cards.
- **Not applied to:** `IncomeCard` (stays as focal solid card), dialogs, nested info boxes, add/edit form toggle cards.

> **Contrast note:** Spec suggested `alpha: 0.30` for the gradient blend; `0.20` was used to ensure `textSecondary` remains above 4.5:1 contrast ratio over the gradient end-color at the conservative edge.

