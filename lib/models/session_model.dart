import 'package:cloud_firestore/cloud_firestore.dart';

// ── Session Status ─────────────────────────────────────────────────────────────

/// Represents the outcome / scheduling state of a session.
enum SessionStatus { scheduled, completed, postponed, cancelled }

/// Extension providing serialization helpers on [SessionStatus].
extension SessionStatusExtension on SessionStatus {
  /// Converts enum value to the Firestore string representation.
  String toValue() => switch (this) {
        SessionStatus.scheduled => 'scheduled',
        SessionStatus.completed => 'completed',
        SessionStatus.postponed => 'postponed',
        SessionStatus.cancelled => 'cancelled',
      };

  /// Human-readable Arabic label for UI display.
  String get arabicLabel => switch (this) {
        SessionStatus.scheduled => 'محجوزة',
        SessionStatus.completed => 'مكتملة',
        SessionStatus.postponed => 'مؤجلة',
        SessionStatus.cancelled => 'ملغاة',
      };
}

/// Parses a raw Firestore string into [SessionStatus].
/// Defaults to [SessionStatus.postponed] on unknown values.
SessionStatus sessionStatusFromValue(String? value) => switch (value) {
      'scheduled' => SessionStatus.scheduled,
      'completed' => SessionStatus.completed,
      'cancelled' => SessionStatus.cancelled,
      _ => SessionStatus.postponed,
    };

// ── Session Model ──────────────────────────────────────────────────────────────

/// Immutable data model representing one therapy session.
///
/// In the multi-account architecture, sessions are stored per user:
/// `users/{uid}/sessions/{sessionId}`
///
/// Rules:
/// - No business logic — only [fromMap], [toMap], and [copyWith].
/// - [remainingAmount] is always derived: `price - paidAmount`, but stored
///   explicitly in Firestore to allow direct querying without client computation.
/// - [date] is the full scheduled instant (date + time).
/// - [durationMinutes] defaults to 60.
class SessionModel {
  final String id;
  final String patientId;
  final DateTime date;
  final int durationMinutes;
  final double price;
  final double paidAmount;
  final double remainingAmount;
  final SessionStatus status;
  final String notes;

  const SessionModel({
    required this.id,
    required this.patientId,
    required this.date,
    this.durationMinutes = 60,
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
    String docId, [
    String? fallbackPatientId,
  ]) {
    final patientId = (map['patientId'] as String?) ?? fallbackPatientId ?? '';
    return SessionModel(
      id: docId,
      patientId: patientId,
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      durationMinutes: (map['durationMinutes'] as num?)?.toInt() ?? 60,
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
      'patientId': patientId,
      'date': Timestamp.fromDate(date),
      'durationMinutes': durationMinutes,
      'price': price,
      'paidAmount': paidAmount,
      'remainingAmount': remainingAmount,
      'status': status.toValue(),
      'notes': notes,
    };
  }

  // ── Immutable update ────────────────────────────────────────────────────────

  SessionModel copyWith({
    String? id,
    String? patientId,
    DateTime? date,
    int? durationMinutes,
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
      durationMinutes: durationMinutes ?? this.durationMinutes,
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
      'SessionModel(id: $id, patientId: $patientId, date: $date, durationMinutes: $durationMinutes, status: ${status.toValue()})';
}
