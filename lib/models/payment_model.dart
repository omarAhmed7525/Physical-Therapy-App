import 'package:physical_therapy/models/session_model.dart';

// ── Payment Status ─────────────────────────────────────────────────────────────

/// Derived payment classification for a session.
enum PaymentStatus { paid, partial, unpaid }

/// Extension providing serialization and display helpers on [PaymentStatus].
extension PaymentStatusExtension on PaymentStatus {
  /// Converts to the string stored in Firestore / used in [PaymentModel.fromMap].
  String toValue() => switch (this) {
        PaymentStatus.paid => 'paid',
        PaymentStatus.partial => 'partial',
        PaymentStatus.unpaid => 'unpaid',
      };

  /// Human-readable Arabic label for UI display.
  String get arabicLabel => switch (this) {
        PaymentStatus.paid => 'مدفوع بالكامل',
        PaymentStatus.partial => 'مدفوع جزئياً',
        PaymentStatus.unpaid => 'غير مدفوع',
      };
}

/// Parses a raw string into [PaymentStatus]. Defaults to [PaymentStatus.unpaid].
PaymentStatus paymentStatusFromValue(String? value) => switch (value) {
      'paid' => PaymentStatus.paid,
      'partial' => PaymentStatus.partial,
      _ => PaymentStatus.unpaid,
    };

// ── Payment Model ──────────────────────────────────────────────────────────────

/// Lightweight value object representing the payment state of a session.
///
/// Not stored as a separate Firestore document — it is always derived from
/// a [SessionModel] via [PaymentModel.fromSession].
///
/// Rules:
/// - No business logic — only [fromMap], [toMap], [fromSession], and [copyWith].
class PaymentModel {
  final String sessionId;
  final double paidAmount;
  final double remainingAmount;
  final PaymentStatus paymentStatus;

  const PaymentModel({
    required this.sessionId,
    required this.paidAmount,
    required this.remainingAmount,
    required this.paymentStatus,
  });

  // ── Factory constructors ────────────────────────────────────────────────────

  /// Creates a [PaymentModel] directly from a [SessionModel].
  /// This is the primary way to obtain a payment view of a session.
  factory PaymentModel.fromSession(SessionModel session) {
    final PaymentStatus status;
    if (session.remainingAmount <= 0) {
      status = PaymentStatus.paid;
    } else if (session.paidAmount > 0) {
      status = PaymentStatus.partial;
    } else {
      status = PaymentStatus.unpaid;
    }

    return PaymentModel(
      sessionId: session.id,
      paidAmount: session.paidAmount,
      remainingAmount: session.remainingAmount,
      paymentStatus: status,
    );
  }

  /// Deserializes from a raw Firestore map.
  factory PaymentModel.fromMap(Map<String, dynamic> map) {
    return PaymentModel(
      sessionId: map['sessionId'] as String? ?? '',
      paidAmount: (map['paidAmount'] as num?)?.toDouble() ?? 0.0,
      remainingAmount: (map['remainingAmount'] as num?)?.toDouble() ?? 0.0,
      paymentStatus: paymentStatusFromValue(map['paymentStatus'] as String?),
    );
  }

  // ── Serialization ───────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() {
    return {
      'sessionId': sessionId,
      'paidAmount': paidAmount,
      'remainingAmount': remainingAmount,
      'paymentStatus': paymentStatus.toValue(),
    };
  }

  // ── Immutable update ────────────────────────────────────────────────────────

  PaymentModel copyWith({
    String? sessionId,
    double? paidAmount,
    double? remainingAmount,
    PaymentStatus? paymentStatus,
  }) {
    return PaymentModel(
      sessionId: sessionId ?? this.sessionId,
      paidAmount: paidAmount ?? this.paidAmount,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      paymentStatus: paymentStatus ?? this.paymentStatus,
    );
  }

  // ── Equality & debugging ────────────────────────────────────────────────────

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaymentModel &&
          runtimeType == other.runtimeType &&
          sessionId == other.sessionId;

  @override
  int get hashCode => sessionId.hashCode;

  @override
  String toString() =>
      'PaymentModel(sessionId: $sessionId, paid: $paidAmount, remaining: $remainingAmount, status: ${paymentStatus.toValue()})';
}
