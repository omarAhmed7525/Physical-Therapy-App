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
