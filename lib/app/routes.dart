import 'package:flutter/material.dart';
import 'package:physical_therapy/features/dashboard/dashboard_view.dart';
import 'package:physical_therapy/features/patients/patients_view.dart';
import 'package:physical_therapy/features/patients/add_patient_view.dart';
import 'package:physical_therapy/features/patients/edit_patient_view.dart';
import 'package:physical_therapy/features/patients/patient_details_view.dart';
import 'package:physical_therapy/features/sessions/sessions_view.dart';
import 'package:physical_therapy/features/sessions/add_session_view.dart';
import 'package:physical_therapy/features/sessions/edit_session_view.dart';
import 'package:physical_therapy/features/reports/reports_view.dart';
import 'package:physical_therapy/features/settings/settings_view.dart';
import 'package:physical_therapy/models/patient_model.dart';
import 'package:physical_therapy/models/session_model.dart';

/// Central route registry — all named routes are defined here.
/// Views never navigate by constructing route strings themselves;
/// they use the constants defined in [AppRoutes].
abstract class AppRoutes {
  // ── Route name constants ──────────────────────────────────────────────────
  static const String dashboard = '/';
  static const String patients = '/patients';
  static const String addPatient = '/patients/add';
  static const String editPatient = '/patients/edit';
  static const String patientDetails = '/patients/details';
  static const String sessions = '/sessions';
  static const String addSession = '/sessions/add';
  static const String editSession = '/sessions/edit';
  static const String reports = '/reports';
  static const String settings = '/settings';

  // ── Route generator ───────────────────────────────────────────────────────
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case dashboard:
        return _fade(const DashboardView());

      case patients:
        return _fade(const PatientsView());

      case addPatient:
        return _slide(const AddPatientView());

      case editPatient:
        final patient = settings.arguments as PatientModel;
        return _slide(EditPatientView(patient: patient));

      case patientDetails:
        final patient = settings.arguments as PatientModel;
        return _fade(PatientDetailsView(patient: patient));

      case AppRoutes.sessions:
        return _fade(const SessionsView());

      case addSession:
        final patientId = settings.arguments as String?;
        return _slide(AddSessionView(patientId: patientId));

      case editSession:
        final session = settings.arguments as SessionModel;
        return _slide(EditSessionView(session: session));

      case reports:
        return _fade(const ReportsView());

      case AppRoutes.settings:
        return _fade(const SettingsView());

      default:
        return _fade(
          Scaffold(
            body: Center(
              child: Text('Route not found: ${settings.name}'),
            ),
          ),
        );
    }
  }

  // ── Transition helpers ────────────────────────────────────────────────────

  /// Fade transition — used for tab-level navigation.
  static PageRoute<T> _fade<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      transitionDuration: const Duration(milliseconds: 250),
    );
  }

  /// Slide-from-right transition — used for detail/form screens.
  static PageRoute<T> _slide<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final tween = Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }
}
