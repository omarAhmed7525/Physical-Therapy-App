import 'dart:math';
import 'package:physical_therapy/models/debt_payment_model.dart';
import 'package:physical_therapy/models/session_model.dart';

/// Pure calculator functions for patient debt and cash-basis income.
class DebtCalculator {
  DebtCalculator._();

  /// Calculates outstanding debt for a patient:
  /// `outstanding(patientId) = max(0, Σ (price - paidAmount) of completed sessions − Σ debtPayments.amount)`
  static double calculateOutstandingDebt({
    required String patientId,
    required List<SessionModel> sessions,
    required List<DebtPaymentModel> debtPayments,
  }) {
    // 1. Sum (price - paidAmount) of that patient's sessions with status == completed
    //    so that overpayments on a session offset older debt.
    final totalBalance = sessions
        .where((s) => s.patientId == patientId && s.status == SessionStatus.completed)
        .fold<double>(0.0, (sum, s) => sum + (s.price - s.paidAmount));

    // 2. Sum of debt payments made by that patient
    final totalPaid = debtPayments
        .where((p) => p.patientId == patientId)
        .fold<double>(0.0, (sum, p) => sum + p.amount);

    return max(0.0, totalBalance - totalPaid);
  }

  /// Calculates current total outstanding debt across ALL patients:
  /// Sum of `calculateOutstandingDebt(patientId)` over all distinct patient IDs.
  static double calculateTotalOutstandingDebt({
    required List<String> patientIds,
    required List<SessionModel> sessions,
    required List<DebtPaymentModel> debtPayments,
  }) {
    double total = 0.0;
    for (final pid in patientIds) {
      total += calculateOutstandingDebt(
        patientId: pid,
        sessions: sessions,
        debtPayments: debtPayments,
      );
    }
    return total;
  }
}

/// Cash basis income for a given month and year:
/// `incomeForMonth = Σ paidAmount of completed sessions in month + Σ debt payments with paidAt in month`
double incomeForMonth({
  required List<SessionModel> sessions,
  required List<DebtPaymentModel> debtPayments,
  required int year,
  required int month,
}) {
  final sessionIncome = sessions.where((s) {
    return s.status == SessionStatus.completed &&
        s.date.year == year &&
        s.date.month == month;
  }).fold<double>(0.0, (sum, s) => sum + s.paidAmount);

  final debtIncome = debtPayments.where((p) {
    return p.paidAt.year == year && p.paidAt.month == month;
  }).fold<double>(0.0, (sum, p) => sum + p.amount);

  return sessionIncome + debtIncome;
}
