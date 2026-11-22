import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Central Firestore access layer.
///
/// This is the **only** place in the codebase that holds a reference to
/// [FirebaseFirestore]. Repositories obtain typed [CollectionReference]s and
/// [DocumentReference]s from here — they never instantiate Firestore directly.
///
/// In the multi-account architecture:
/// All user data is isolated per authenticated user:
/// `users/{uid}/patients/{pid}`
/// `users/{uid}/sessions/{sid}`
/// `users/{uid}/commissionHistory/{id}`
/// `users/{uid}/debtPayments/{id}`
/// `users/{uid}/meta/migration`
class FirebaseService {
  FirebaseService._();

  static final FirebaseService instance = FirebaseService._();

  // ── Firestore instance ─────────────────────────────────────────────────────

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Current User Helper ────────────────────────────────────────────────────

  /// Current signed-in user ID. Throws [StateError] if not authenticated.
  String get currentUid {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Cannot access Firestore without an authenticated user.');
    }
    return user.uid;
  }

  /// Reference to the current user's document: `users/{uid}`.
  DocumentReference<Map<String, dynamic>> get userDoc =>
      _db.collection('users').doc(currentUid);

  // ── Scoped Collection References (users/{uid}/...) ────────────────────────

  /// Patients collection: `users/{uid}/patients`
  CollectionReference<Map<String, dynamic>> get patientsCollection =>
      userDoc.collection('patients');

  /// Sessions collection: `users/{uid}/sessions`
  CollectionReference<Map<String, dynamic>> get sessionsCollection =>
      userDoc.collection('sessions');

  /// Commission history collection: `users/{uid}/commissionHistory`
  CollectionReference<Map<String, dynamic>> get commissionHistoryCollection =>
      userDoc.collection('commissionHistory');

  /// Debt payments collection: `users/{uid}/debtPayments`
  CollectionReference<Map<String, dynamic>> get debtPaymentsCollection =>
      userDoc.collection('debtPayments');

  /// Migration metadata doc: `users/{uid}/meta/migration`
  DocumentReference<Map<String, dynamic>> get migrationMetaDoc =>
      userDoc.collection('meta').doc('migration');

  // ── Scoped Document References ─────────────────────────────────────────────

  /// Reference to a specific patient document under current user.
  DocumentReference<Map<String, dynamic>> patientDoc(String patientId) =>
      patientsCollection.doc(patientId);

  /// Reference to a specific session document under current user.
  DocumentReference<Map<String, dynamic>> sessionDoc(String sessionId) =>
      sessionsCollection.doc(sessionId);

  /// Reference to a specific commission history document under current user.
  DocumentReference<Map<String, dynamic>> commissionHistoryDoc(String id) =>
      commissionHistoryCollection.doc(id);

  /// Reference to a specific debt payment document under current user.
  DocumentReference<Map<String, dynamic>> debtPaymentDoc(String id) =>
      debtPaymentsCollection.doc(id);

  // ── Batch & Transaction Helpers ────────────────────────────────────────────

  /// Returns a new [WriteBatch] for atomic multi-document writes.
  WriteBatch get batch => _db.batch();

  /// Runs a [Transaction] against Firestore.
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler,
  ) =>
      _db.runTransaction(transactionHandler);

  // ── Scoped Query Helpers (Flat queries, NO collection groups) ─────────────

  /// Query for all sessions belonging to [patientId], ordered by date descending.
  Query<Map<String, dynamic>> sessionsForPatient(String patientId) =>
      sessionsCollection
          .where('patientId', isEqualTo: patientId)
          .orderBy('date', descending: true);

  /// Query for all sessions belonging to [patientId] filtered by [status].
  Query<Map<String, dynamic>> sessionsByStatus(
    String patientId,
    String status,
  ) =>
      sessionsCollection
          .where('patientId', isEqualTo: patientId)
          .where('status', isEqualTo: status);

  /// Query for sessions within a date range across current user's sessions.
  /// Both [from] and [to] are inclusive.
  Query<Map<String, dynamic>> sessionsByDateRange({
    required DateTime from,
    required DateTime to,
  }) =>
      sessionsCollection
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

  /// Query for today's sessions across current user's sessions.
  Query<Map<String, dynamic>> todaySessionsQuery() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return sessionsCollection
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

  /// Query for ALL sessions for the current user, ordered by date descending.
  Query<Map<String, dynamic>> allSessionsQuery() =>
      sessionsCollection.orderBy('date', descending: true);

  /// Query for ALL commission history logs for the current user, ordered by paidAt descending.
  Query<Map<String, dynamic>> commissionHistoryQuery() =>
      commissionHistoryCollection.orderBy('paidAt', descending: true);

  /// Query for commission history logs for a specific patient.
  Query<Map<String, dynamic>> commissionHistoryForPatient(String patientId) =>
      commissionHistoryCollection
          .where('patientId', isEqualTo: patientId)
          .orderBy('paidAt', descending: true);

  /// Query for ALL debt payments for the current user, ordered by paidAt descending.
  Query<Map<String, dynamic>> debtPaymentsQuery() =>
      debtPaymentsCollection.orderBy('paidAt', descending: true);

  /// Query for debt payments for a specific patient.
  Query<Map<String, dynamic>> debtPaymentsForPatient(String patientId) =>
      debtPaymentsCollection
          .where('patientId', isEqualTo: patientId)
          .orderBy('paidAt', descending: true);

  // ── Legacy Single-User Access (For migration only) ─────────────────────────

  /// Top-level legacy patients collection: `patients`
  CollectionReference<Map<String, dynamic>> get legacyPatientsCollection =>
      _db.collection('patients');

  /// Top-level legacy patient doc: `patients/{patientId}`
  DocumentReference<Map<String, dynamic>> legacyPatientDoc(String patientId) =>
      _db.collection('patients').doc(patientId);

  /// Legacy sessions subcollection: `patients/{patientId}/sessions`
  CollectionReference<Map<String, dynamic>> legacySessionsCollection(
    String patientId,
  ) =>
      _db.collection('patients').doc(patientId).collection('sessions');

  /// Legacy commissionHistory subcollection: `patients/{patientId}/commissionHistory`
  CollectionReference<Map<String, dynamic>> legacyCommissionHistoryCollection(
    String patientId,
  ) =>
      _db
          .collection('patients')
          .doc(patientId)
          .collection('commissionHistory');
}
