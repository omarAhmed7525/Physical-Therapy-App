import 'package:cloud_firestore/cloud_firestore.dart';

/// Immutable data model representing a physiotherapy patient.
///
/// Rules:
/// - No business logic — only [fromMap], [toMap], and [copyWith].
/// - [location] is nullable; use [clearLocation] in [copyWith]
///   to explicitly set it to null.
class PatientModel {
  final String id;
  final String name;
  final String phone;
  final String address;

  /// Optional GPS coordinates stored as a Firestore [GeoPoint].
  final GeoPoint? location;

  final String medicalNotes;
  final DateTime createdAt;

  // ── Commission Tracking Fields ─────────────────────────────────────────────
  final bool commissionEnabled;
  final double? commissionAmount;
  final int commissionSessionsCount;

  // ── Treatment Plan / Package (Workstream C4) ──────────────────────────────
  final int? planTotalSessions;
  final DateTime? planStartDate;

  const PatientModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    this.location,
    required this.medicalNotes,
    required this.createdAt,
    this.commissionEnabled = false,
    this.commissionAmount,
    this.commissionSessionsCount = 0,
    this.planTotalSessions,
    this.planStartDate,
  });

  // ── Convenience Getters ────────────────────────────────────────────────────

  /// 'inactive' = commission not enabled, or 0 sessions counted yet.
  /// 'inProgress' = 1 or 2 sessions counted toward the current cycle.
  /// 'due' = 3 sessions counted — a full cycle is complete and payment is owed.
  String get commissionCycleState {
    if (!commissionEnabled || commissionSessionsCount == 0) return 'inactive';
    if (commissionSessionsCount >= 3) return 'due';
    return 'inProgress';
  }

  // ── Deserialization ─────────────────────────────────────────────────────────

  factory PatientModel.fromMap(Map<String, dynamic> map, String docId) {
    return PatientModel(
      id: docId,
      name: map['name'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      address: map['address'] as String? ?? '',
      location: map['location'] as GeoPoint?,
      medicalNotes: map['medicalNotes'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      commissionEnabled: map['commissionEnabled'] as bool? ?? false,
      commissionAmount: (map['commissionAmount'] as num?)?.toDouble(),
      commissionSessionsCount: map['commissionSessionsCount'] as int? ?? 0,
      planTotalSessions: (map['planTotalSessions'] as num?)?.toInt(),
      planStartDate: (map['planStartDate'] as Timestamp?)?.toDate(),
    );
  }

  // ── Serialization ───────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'address': address,
      'location': location,
      'medicalNotes': medicalNotes,
      'createdAt': Timestamp.fromDate(createdAt),
      'commissionEnabled': commissionEnabled,
      'commissionAmount': commissionAmount,
      'commissionSessionsCount': commissionSessionsCount,
      'planTotalSessions': planTotalSessions,
      'planStartDate':
          planStartDate != null ? Timestamp.fromDate(planStartDate!) : null,
    };
  }

  // ── Immutable update ────────────────────────────────────────────────────────

  /// Pass [clearLocation] = true to explicitly set [location] to null.
  /// Pass [clearPlan] = true to clear planTotalSessions and planStartDate.
  PatientModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? address,
    GeoPoint? location,
    bool clearLocation = false,
    String? medicalNotes,
    DateTime? createdAt,
    bool? commissionEnabled,
    double? commissionAmount,
    int? commissionSessionsCount,
    bool clearCommissionAmount = false,
    int? planTotalSessions,
    DateTime? planStartDate,
    bool clearPlan = false,
  }) {
    return PatientModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      location: clearLocation ? null : (location ?? this.location),
      medicalNotes: medicalNotes ?? this.medicalNotes,
      createdAt: createdAt ?? this.createdAt,
      commissionEnabled: commissionEnabled ?? this.commissionEnabled,
      commissionAmount: clearCommissionAmount
          ? null
          : (commissionAmount ?? this.commissionAmount),
      commissionSessionsCount:
          commissionSessionsCount ?? this.commissionSessionsCount,
      planTotalSessions:
          clearPlan ? null : (planTotalSessions ?? this.planTotalSessions),
      planStartDate:
          clearPlan ? null : (planStartDate ?? this.planStartDate),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PatientModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'PatientModel(id: $id, name: $name, planTotalSessions: $planTotalSessions)';
}
