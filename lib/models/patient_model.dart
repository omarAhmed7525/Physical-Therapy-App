import 'package:cloud_firestore/cloud_firestore.dart';

/// Immutable data model representing a physiotherapy patient.
///
/// Rules:
/// - No business logic — only [fromMap], [toMap], and [copyWith].
/// - [location] is nullable; use [_ClearLocation] sentinel in [copyWith]
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

  const PatientModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    this.location,
    required this.medicalNotes,
    required this.createdAt,
  });

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
    );
  }

  // ── Serialization ───────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'address': address,
      'location': location, // null is a valid Firestore value (field not set)
      'medicalNotes': medicalNotes,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // ── Immutable update ────────────────────────────────────────────────────────

  /// Pass [clearLocation] = true to explicitly set [location] to null.
  PatientModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? address,
    GeoPoint? location,
    bool clearLocation = false,
    String? medicalNotes,
    DateTime? createdAt,
  }) {
    return PatientModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      location: clearLocation ? null : (location ?? this.location),
      medicalNotes: medicalNotes ?? this.medicalNotes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // ── Equality & debugging ────────────────────────────────────────────────────

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PatientModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'PatientModel(id: $id, name: $name, phone: $phone)';
}
