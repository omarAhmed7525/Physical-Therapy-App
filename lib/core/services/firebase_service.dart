import 'package:cloud_firestore/cloud_firestore.dart';

/// Central Firestore access layer.
///
/// This is the **only** place in the codebase that holds a reference to
/// [FirebaseFirestore]. Repositories obtain typed [CollectionReference]s and
/// [DocumentReference]s from here — they never instantiate Firestore directly.
///
/// Usage:
/// ```dart
/// final patientsRef = FirebaseService.instance.patientsCollection;
/// final sessionsRef = FirebaseService.instance.sessionsCollection('patientId');
/// ```
class FirebaseService {
  FirebaseService._();

  static final FirebaseService instance = FirebaseService._();

  // ── Firestore instance ─────────────────────────────────────────────────────

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Collection references ──────────────────────────────────────────────────

  /// Top-level `patients` collection.
  CollectionReference<Map<String, dynamic>> get patientsCollection =>
      _db.collection('patients');

  /// `sessions` subcollection under a specific patient.
  ///
  /// Path: `patients/{patientId}/sessions`
  CollectionReference<Map<String, dynamic>> sessionsCollection(
    String patientId,
  ) =>
      _db.collection('patients').doc(patientId).collection('sessions');

  // ── Document references ────────────────────────────────────────────────────

  /// Reference to a specific patient document.
  DocumentReference<Map<String, dynamic>> patientDoc(String patientId) =>
      _db.collection('patients').doc(patientId);

  /// Reference to a specific session document under a patient.
  DocumentReference<Map<String, dynamic>> sessionDoc(
    String patientId,
    String sessionId,
  ) =>
      _db
          .collection('patients')
          .doc(patientId)
          .collection('sessions')
          .doc(sessionId);

  // ── Batch & transaction helpers ────────────────────────────────────────────

  /// Returns a new [WriteBatch] for atomic multi-document writes.
  WriteBatch get batch => _db.batch();

  /// Runs a [Transaction] against Firestore.
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler,
  ) =>
      _db.runTransaction(transactionHandler);

  // ── Query helpers ──────────────────────────────────────────────────────────

  /// Returns a query for all sessions of a patient filtered by [status].
  ///
  /// Example:
  /// ```dart
  /// final q = FirebaseService.instance.sessionsByStatus('p1', 'completed');
  /// ```
  Query<Map<String, dynamic>> sessionsByStatus(
    String patientId,
    String status,
  ) =>
      sessionsCollection(patientId).where('status', isEqualTo: status);

  /// Returns a query for sessions of a patient within a date range.
  /// Both [from] and [to] are inclusive.
  Query<Map<String, dynamic>> sessionsByDateRange(
    String patientId, {
    required DateTime from,
    required DateTime to,
  }) =>
      sessionsCollection(patientId)
          .where(
            'date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(
              DateTime(from.year, from.month, from.day),
            ),
          )
          .where(
            'date',
            isLessThanOrEqualTo: Timestamp.fromDate(
              DateTime(to.year, to.month, to.day, 23, 59, 59),
            ),
          )
          .orderBy('date', descending: false);

  /// Returns a query for all sessions across ALL patients within a date range.
  /// Used by the reports feature to aggregate monthly income.
  ///
  /// NOTE: This uses a collection group query — Firestore requires a composite
  /// index on `sessions` for `date` (ascending). The index will be created
  /// automatically when you first run the query in the Firebase console.
  Query<Map<String, dynamic>> allSessionsByDateRange({
    required DateTime from,
    required DateTime to,
  }) =>
      _db
          .collectionGroup('sessions')
          .where(
            'date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(
              DateTime(from.year, from.month, from.day),
            ),
          )
          .where(
            'date',
            isLessThanOrEqualTo: Timestamp.fromDate(
              DateTime(to.year, to.month, to.day, 23, 59, 59),
            ),
          )
          .orderBy('date', descending: false);

  /// Returns a query for today's sessions across ALL patients.
  /// Used by the dashboard.
  Query<Map<String, dynamic>> todaySessionsQuery() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return _db
        .collectionGroup('sessions')
        .where(
          'date',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
        .where(
          'date',
          isLessThanOrEqualTo: Timestamp.fromDate(endOfDay),
        )
        .orderBy('date', descending: false);
  }

  /// Returns a query for ALL sessions across ALL patients.
  Query<Map<String, dynamic>> allSessionsQuery() =>
      _db.collectionGroup('sessions').orderBy('date', descending: true);

  /// Returns a query for ALL commission history logs across ALL patients.
  Query<Map<String, dynamic>> commissionHistoryQuery() =>
      _db.collectionGroup('commissionHistory').orderBy('paidAt', descending: true);
}
