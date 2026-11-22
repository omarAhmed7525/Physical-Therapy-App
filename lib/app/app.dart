import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:physical_therapy/app/routes.dart';
import 'package:physical_therapy/core/constants/owner_config.dart';
import 'package:physical_therapy/core/services/migration_service.dart';
import 'package:physical_therapy/core/theme/theme_provider.dart';
import 'package:physical_therapy/core/theme/light_theme.dart';
import 'package:physical_therapy/core/theme/dark_theme.dart';
import 'package:physical_therapy/features/auth/login_screen.dart';
import 'package:physical_therapy/features/dashboard/dashboard_view.dart';
import 'package:physical_therapy/features/migration/migration_screen.dart';
import 'package:physical_therapy/providers/debt_provider.dart';
import 'package:physical_therapy/providers/patient_provider.dart';
import 'package:physical_therapy/providers/session_provider.dart';
import 'package:physical_therapy/widgets/loading_widget.dart';
import 'package:provider/provider.dart';

/// Root application widget.
///
/// Provider split:
/// - [ThemeProvider] stays in the **top-level** MultiProvider because it reads
///   only from SharedPreferences and must exist even before authentication.
/// - [PatientProvider] and [SessionProvider] are placed in a **second**
///   MultiProvider keyed by `ValueKey(user.uid)` wrapping ONLY the authenticated branch,
///   so providers are fully recreated whenever a different account signs in.
class PhysioApp extends StatelessWidget {
  const PhysioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return StreamBuilder<User?>(
            stream: FirebaseAuth.instance.userChanges(),
            initialData: FirebaseAuth.instance.currentUser,
            builder: (context, snapshot) {
              final user = snapshot.data;

              return MaterialApp(
                title: 'عيادة العلاج الطبيعي',
                debugShowCheckedModeBanner: false,
                themeMode: themeProvider.themeMode,
                theme: LightTheme.build(),
                darkTheme: DarkTheme.build(),
                onGenerateRoute: AppRoutes.generateRoute,
                builder: (context, child) {
                  Widget content = Directionality(
                    textDirection: TextDirection.rtl,
                    child: child!,
                  );

                  if (user != null) {
                    content = MultiProvider(
                      key: ValueKey(user.uid),
                      providers: [
                        ChangeNotifierProvider(create: (_) => PatientProvider()),
                        ChangeNotifierProvider(create: (_) => SessionProvider()),
                        ChangeNotifierProvider(create: (_) => DebtProvider()),
                      ],
                      child: content,
                    );
                  }

                  return content;
                },
                home: const AuthGate(),
              );
            },
          );
        },
      ),
    );
  }
}

/// Reactive authentication gate.
///
/// Listens to [FirebaseAuth.instance.userChanges] and shows:
/// - A loading spinner while the auth state is being determined.
/// - [LoginScreen] when the user is signed out.
/// - [MigrationScreen] if the signed-in user is `kLegacyOwnerUid` and migration is pending.
/// - The authenticated dashboard tree when signed in and ready.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Scaffold(
            body: Center(child: LoadingWidget()),
          );
        }

        final user = snapshot.data;
        if (user != null) {
          // If legacy owner, check migration status first
          if (user.uid == kLegacyOwnerUid) {
            return _LegacyOwnerMigrationGate(user: user);
          }

          // Any new / non-legacy user goes directly to authenticated tree
          return const DashboardView();
        }

        return const LoginScreen();
      },
    );
  }
}

class _LegacyOwnerMigrationGate extends StatefulWidget {
  final User user;

  const _LegacyOwnerMigrationGate({required this.user});

  @override
  State<_LegacyOwnerMigrationGate> createState() =>
      _LegacyOwnerMigrationGateState();
}

class _LegacyOwnerMigrationGateState extends State<_LegacyOwnerMigrationGate> {
  final MigrationService _migrationService = MigrationService();
  bool? _isMigrationDone;
  String? _checkError;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    try {
      final done = await _migrationService.isMigrationDone();
      if (mounted) {
        setState(() {
          _isMigrationDone = done;
          _checkError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _checkError = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkError != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'حدث خطأ في التحقق من حالة البيانات: $_checkError',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _checkStatus,
                  child: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_isMigrationDone == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_isMigrationDone == false) {
      return MigrationScreen(
        onMigrationSuccess: () {
          setState(() {
            _isMigrationDone = true;
          });
        },
      );
    }

    return const DashboardView();
  }
}
