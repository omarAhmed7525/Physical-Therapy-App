import 'package:cloud_firestore/cloud_firestore.dart';

/// Immutable model representing a patient debt repayment document stored at:
/// `users/{uid}/debtPayments/{id}`
class DebtPaymentModel {
  final String id;
  final String patientId;
  final double amount;
  final DateTime paidAt;
  final String? note;

  const DebtPaymentModel({
    required this.id,
    required this.patientId,
    required this.amount,
    required this.paidAt,
    this.note,
  });

  factory DebtPaymentModel.fromMap(Map<String, dynamic> map, String docId) {
    return DebtPaymentModel(
      id: docId,
      patientId: map['patientId'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      paidAt: (map['paidAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      note: map['note'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'patientId': patientId,
      'amount': amount,
      'paidAt': Timestamp.fromDate(paidAt),
      if (note != null && note!.isNotEmpty) 'note': note,
    };
  }

  DebtPaymentModel copyWith({
    String? id,
    String? patientId,
    double? amount,
    DateTime? paidAt,
    String? note,
  }) {
    return DebtPaymentModel(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      amount: amount ?? this.amount,
      paidAt: paidAt ?? this.paidAt,
      note: note ?? this.note,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DebtPaymentModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'DebtPaymentModel(id: $id, patientId: $patientId, amount: $amount, paidAt: $paidAt)';
}
