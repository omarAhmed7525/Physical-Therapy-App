import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:physical_therapy/app/routes.dart';
import 'package:physical_therapy/core/theme/theme_provider.dart';
import 'package:physical_therapy/core/theme/light_theme.dart';
import 'package:physical_therapy/core/theme/dark_theme.dart';
import 'package:physical_therapy/features/auth/login_screen.dart';
import 'package:physical_therapy/providers/patient_provider.dart';
import 'package:physical_therapy/providers/session_provider.dart';
import 'package:provider/provider.dart';

/// Root application widget.
///
/// Provider split:
/// - [ThemeProvider] stays in the **top-level** MultiProvider because it reads
///   only from SharedPreferences and must exist even before authentication.
/// - [PatientProvider] and [SessionProvider] are placed in a **second**
///   MultiProvider that wraps ONLY the authenticated branch, so they are
///   constructed (and their Firestore listeners started) only after the
///   doctor has signed in.
class PhysioApp extends StatelessWidget {
  const PhysioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      // ── Providers that do NOT touch Firestore ────────────────────────────
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'عيادة العلاج الطبيعي',
            debugShowCheckedModeBanner: false,
            themeMode: themeProvider.themeMode,
            theme: LightTheme.build(),
            darkTheme: DarkTheme.build(),
            onGenerateRoute: AppRoutes.generateRoute,
            builder: (context, child) {
              return Directionality(
                textDirection: TextDirection.rtl,
                child: child!,
              );
            },
            home: const AuthGate(),
          );
        },
      ),
    );
  }
}

/// Reactive authentication gate.
///
/// Listens to [FirebaseAuth.instance.authStateChanges] and shows:
/// - A loading spinner while the auth state is being determined.
/// - [LoginScreen] when the user is signed out.
/// - The home screen (wrapped in Firestore providers) when signed in.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // ── Waiting for auth state ───────────────────────────────────────────
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // ── Authenticated — inject Firestore providers and show dashboard ────
        if (snapshot.hasData) {
          return MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => PatientProvider()),
              ChangeNotifierProvider(create: (_) => SessionProvider()),
            ],
            // Use a nested Navigator so the authenticated sub-tree has its
            // own navigation stack independent of the MaterialApp root.
            child: Navigator(
              onGenerateRoute: AppRoutes.generateRoute,
              initialRoute: AppRoutes.dashboard,
            ),
          );
        }

        // ── Not authenticated ────────────────────────────────────────────────
        return const LoginScreen();
      },
    );
  }
}
