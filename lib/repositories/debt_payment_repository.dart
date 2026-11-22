import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:physical_therapy/core/services/firebase_service.dart';
import 'package:physical_therapy/models/debt_payment_model.dart';

class DebtPaymentRepository {
  final FirebaseService _firebaseService = FirebaseService.instance;

  /// Stream of all debt payments for the current user, ordered by paidAt descending.
  Stream<List<DebtPaymentModel>> getDebtPaymentsStream() {
    return _firebaseService.debtPaymentsQuery().snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return DebtPaymentModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  /// Adds a new debt payment doc to `users/{uid}/debtPayments`.
  Future<String> addDebtPayment({
    required String patientId,
    required double amount,
    String? note,
  }) async {
    final docRef = await _firebaseService.debtPaymentsCollection.add({
      'patientId': patientId,
      'amount': amount,
      'paidAt': FieldValue.serverTimestamp(),
      if (note != null && note.isNotEmpty) 'note': note,
    });
    return docRef.id;
  }
}
