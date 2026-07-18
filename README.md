# Physical Therapy Clinic Manager

A Flutter mobile application for managing a physiotherapy clinic's daily operations — patient records, treatment sessions, and income tracking — backed by Firebase.

## Overview

This app helps a physical therapy practitioner manage their clinic from their phone: keeping patient records, scheduling and logging treatment sessions, tracking payments, and reviewing income reports — all synced in real time through Firebase.

It is a **single-user application**, secured with Firebase Authentication so that only the clinic owner can access patient data.

## Features

-  **Secure Login**         — Email/password authentication gates all access to patient data
-  **Patient Management**   — Add, edit, and view patient records (name, contact info, medical notes, optional location)
-  **Session Tracking**     — Log and manage treatment sessions per patient
-  **Income & Reports**     — Dashboard view of today's sessions and income summaries
-  **Light & Dark Theme**   — Full theme support across the app
-  **Location Support**     — Optional geocoding for patient addresses
-  **Cross-platform**       — Built with Flutter (Android primary target)

## Tech Stack

- **Flutter** & **Dart**
- **Firebase Authentication** — single-user email/password login
- **Cloud Firestore** — real-time database for patients & sessions
- **Provider** — state management
- **Google Fonts**, **geocoding**, **url_launcher**, **intl**

## Architecture

The app follows a feature-based folder structure:

```
lib/
    app/             # App root widget, routing, AuthGate
    core/            # Theme, constants, shared services & utils
    features/        # Screens grouped by feature (auth, dashboard, patients, sessions, reports, settings)
    models/          # Data models (Patient, Session, Payment)
    providers/       # State management (ChangeNotifier-based)
    repositories/    # Firestore data access layer
    widgets/         # Shared reusable widgets
```

### Authentication flow

The app is wrapped in an `AuthGate` that listens to Firebase's auth state:
- **Signed out** → shows the login screen
- **Signed in** → mounts the data providers (which start listening to Firestore) and shows the main app

This ensures Firestore is never queried before the user is authenticated, and pairs with server-side Firestore Security Rules that require `request.auth != null` for all reads/writes.

## Getting Started

This repo does not include Firebase configuration files (`google-services.json`, `GoogleService-Info.plist`, `firebase_options.dart`) for security reasons. To run this project yourself:

1. Clone the repo
2. Create your own Firebase project
3. Enable **Authentication** (Email/Password) and **Cloud Firestore**
4. Run `flutterfire configure` to generate your own `firebase_options.dart`
5. Set Firestore Security Rules to require authentication:
   ```javascript
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /{document=**} {
         allow read, write: if request.auth != null;
       }
     }
   }
   ```
6. `flutter pub get`
7. `flutter run`

## Note

This project was built as a real client solution for a physiotherapy clinic. All patient data lives in a private, authenticated Firestore instance — no real patient information is included in this repository.
