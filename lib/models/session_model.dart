import 'package:cloud_firestore/cloud_firestore.dart';

// ── Session Status ─────────────────────────────────────────────────────────────

/// Represents the outcome / scheduling state of a session.
enum SessionStatus { completed, postponed, cancelled }

/// Extension providing serialization helpers on [SessionStatus].
extension SessionStatusExtension on SessionStatus {
  /// Converts enum value to the Firestore string representation.
  String toValue() => switch (this) {
        SessionStatus.completed => 'completed',
        SessionStatus.postponed => 'postponed',
        SessionStatus.cancelled => 'cancelled',
      };

  /// Human-readable Arabic label for UI display.
  String get arabicLabel => switch (this) {
        SessionStatus.completed => 'مكتملة',
        SessionStatus.postponed => 'مؤجلة',
        SessionStatus.cancelled => 'ملغاة',
      };
}

/// Parses a raw Firestore string into [SessionStatus].
/// Defaults to [SessionStatus.postponed] on unknown values.
SessionStatus sessionStatusFromValue(String? value) => switch (value) {
      'completed' => SessionStatus.completed,
      'cancelled' => SessionStatus.cancelled,
      _ => SessionStatus.postponed,
    };

// ── Session Model ──────────────────────────────────────────────────────────────

/// Immutable data model representing one therapy session.
///
/// Sessions are stored as a subcollection under their patient:
/// `patients/{patientId}/sessions/{sessionId}`
///
/// Rules:
/// - No business logic — only [fromMap], [toMap], and [copyWith].
/// - [remainingAmount] is always derived: `price - paidAmount`, but stored
///   explicitly in Firestore to allow direct querying without client computation.
class SessionModel {
  final String id;
  final String patientId;
  final DateTime date;

  /// Display time string, e.g. "10:30 ص" — stored as-is from UI input.
  final String time;

  final double price;
  final double paidAmount;
  final double remainingAmount;
  final SessionStatus status;
  final String notes;

  const SessionModel({
    required this.id,
    required this.patientId,
    required this.date,
    required this.time,
    required this.price,
    required this.paidAmount,
    required this.remainingAmount,
    required this.status,
    required this.notes,
  });

  // ── Convenience getters ─────────────────────────────────────────────────────

  /// True when the session has been paid in full.
  bool get isFullyPaid => remainingAmount <= 0;

  /// True when the session occurred today.
  bool get isToday {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  // ── Deserialization ─────────────────────────────────────────────────────────

  factory SessionModel.fromMap(
    Map<String, dynamic> map,
    String docId,
    String patientId,
  ) {
    return SessionModel(
      id: docId,
      patientId: patientId,
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      time: map['time'] as String? ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      paidAmount: (map['paidAmount'] as num?)?.toDouble() ?? 0.0,
      remainingAmount: (map['remainingAmount'] as num?)?.toDouble() ?? 0.0,
      status: sessionStatusFromValue(map['status'] as String?),
      notes: map['notes'] as String? ?? '',
    );
  }

  // ── Serialization ───────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),
      'time': time,
      'price': price,
      'paidAmount': paidAmount,
      'remainingAmount': remainingAmount,
      'status': status.toValue(),
      'notes': notes,
      // patientId is implicit from the subcollection path — not stored as a field
    };
  }

  // ── Immutable update ────────────────────────────────────────────────────────

  SessionModel copyWith({
    String? id,
    String? patientId,
    DateTime? date,
    String? time,
    double? price,
    double? paidAmount,
    double? remainingAmount,
    SessionStatus? status,
    String? notes,
  }) {
    return SessionModel(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      date: date ?? this.date,
      time: time ?? this.time,
      price: price ?? this.price,
      paidAmount: paidAmount ?? this.paidAmount,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      status: status ?? this.status,
      notes: notes ?? this.notes,
    );
  }

  // ── Equality & debugging ────────────────────────────────────────────────────

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'SessionModel(id: $id, patientId: $patientId, date: $date, status: ${status.toValue()})';
}
