import 'dart:async';
import 'package:flutter/material.dart';
import 'package:physical_therapy/core/utils/debt_calculator.dart';
import 'package:physical_therapy/models/debt_payment_model.dart';
import 'package:physical_therapy/models/session_model.dart';
import 'package:physical_therapy/repositories/debt_payment_repository.dart';

class DebtProvider extends ChangeNotifier {
  final DebtPaymentRepository _repository = DebtPaymentRepository();

  List<DebtPaymentModel> _debtPayments = [];
  bool _isLoading = false;
  String? _error;
  StreamSubscription<List<DebtPaymentModel>>? _subscription;

  List<DebtPaymentModel> get debtPayments => List.unmodifiable(_debtPayments);
  bool get isLoading => _isLoading;
  String? get error => _error;

  DebtProvider() {
    _listenToDebtPayments();
  }

  void _listenToDebtPayments() {
    _isLoading = true;
    notifyListeners();

    _subscription?.cancel();
    _subscription = _repository.getDebtPaymentsStream().listen(
      (paymentsList) {
        _debtPayments = paymentsList;
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (err) {
        _isLoading = false;
        _error = err.toString();
        notifyListeners();
      },
    );
  }

  /// Calculates outstanding debt for a patient.
  double getPatientOutstanding(String patientId, List<SessionModel> sessions) {
    return DebtCalculator.calculateOutstandingDebt(
      patientId: patientId,
      sessions: sessions,
      debtPayments: _debtPayments,
    );
  }

  /// Records a debt repayment.
  /// The session documents are NEVER modified by this.
  Future<void> addPayment({
    required String patientId,
    required double amount,
    String? note,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _repository.addDebtPayment(
        patientId: patientId,
        amount: amount,
        note: note,
      );
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
