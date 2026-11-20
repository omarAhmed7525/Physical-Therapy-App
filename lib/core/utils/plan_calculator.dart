import 'dart:math';
import 'package:physical_therapy/models/patient_model.dart';
import 'package:physical_therapy/models/session_model.dart';

/// Low threshold for remaining plan sessions
const int kPlanLowThreshold = 2;

enum PlanState { none, normal, low, finished }

/// Pure calculator functions for treatment plans / packages.
class PlanCalculator {
  PlanCalculator._();

  /// Calculates used sessions in current plan:
  /// `used = count of that patient's sessions with status == completed and date >= planStartDate`
  static int calculateUsedSessions({
    required PatientModel patient,
    required List<SessionModel> sessions,
  }) {
    if (patient.planTotalSessions == null || patient.planStartDate == null) {
      return 0;
    }

    return sessions.where((s) {
      return s.patientId == patient.id &&
          s.status == SessionStatus.completed &&
          !s.date.isBefore(patient.planStartDate!);
    }).length;
  }

  /// Calculates remaining sessions in current plan:
  /// `remaining = max(0, total − used)`
  static int calculateRemainingSessions({
    required PatientModel patient,
    required List<SessionModel> sessions,
  }) {
    if (patient.planTotalSessions == null || patient.planStartDate == null) {
      return 0;
    }
    final used = calculateUsedSessions(patient: patient, sessions: sessions);
    return max(0, patient.planTotalSessions! - used);
  }

  /// Returns the current state of the plan:
  /// - `none`: no plan configured
  /// - `finished`: remaining == 0
  /// - `low`: 0 < remaining <= kPlanLowThreshold (2)
  /// - `normal`: remaining > kPlanLowThreshold
  static PlanState getPlanState({
    required PatientModel patient,
    required List<SessionModel> sessions,
  }) {
    if (patient.planTotalSessions == null || patient.planStartDate == null) {
      return PlanState.none;
    }
    final remaining = calculateRemainingSessions(
      patient: patient,
      sessions: sessions,
    );
    if (remaining == 0) return PlanState.finished;
    if (remaining <= kPlanLowThreshold) return PlanState.low;
    return PlanState.normal;
  }
}
