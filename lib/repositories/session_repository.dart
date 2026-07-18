import 'package:physical_therapy/core/services/firebase_service.dart';
import 'package:physical_therapy/models/session_model.dart';

class SessionRepository {
  final FirebaseService _firebaseService = FirebaseService.instance;

  /// Fetch all sessions for a specific patient.
  Future<List<SessionModel>> fetchSessionsForPatient(String patientId) async {
    final snapshot = await _firebaseService
        .sessionsCollection(patientId)
        .orderBy('date', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      return SessionModel.fromMap(doc.data(), doc.id, patientId);
    }).toList();
  }

  /// Add a new session under a patient's subcollection.
  Future<String> addSession(SessionModel session) async {
    final docRef = await _firebaseService
        .sessionsCollection(session.patientId)
        .add(session.toMap());
    return docRef.id;
  }

  /// Update an existing session.
  Future<void> updateSession(SessionModel session) async {
    await _firebaseService
        .sessionDoc(session.patientId, session.id)
        .update(session.toMap());
  }

  /// Delete a session.
  Future<void> deleteSession(String patientId, String sessionId) async {
    await _firebaseService.sessionDoc(patientId, sessionId).delete();
  }

  /// Stream of today's sessions across all patients (using Collection Group).
  Stream<List<SessionModel>> getTodaySessionsStream() {
    return _firebaseService.todaySessionsQuery().snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final pathSegments = doc.reference.path.split('/');
        final patientId = pathSegments.length >= 2 ? pathSegments[1] : '';
        return SessionModel.fromMap(doc.data(), doc.id, patientId);
      }).toList();
    });
  }

  /// Stream of ALL sessions across all patients (using Collection Group).
  Stream<List<SessionModel>> getAllSessionsStream() {
    return _firebaseService.allSessionsQuery().snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final pathSegments = doc.reference.path.split('/');
        final patientId = pathSegments.length >= 2 ? pathSegments[1] : '';
        return SessionModel.fromMap(doc.data(), doc.id, patientId);
      }).toList();
    });
  }

  /// Fetch all sessions within a date range across all patients (for reports).
  Future<List<SessionModel>> fetchAllSessionsByDateRange(
      DateTime from, DateTime to) async {
    final snapshot = await _firebaseService
        .allSessionsByDateRange(from: from, to: to)
        .get();

    return snapshot.docs.map((doc) {
      final pathSegments = doc.reference.path.split('/');
      final patientId = pathSegments.length >= 2 ? pathSegments[1] : '';
      return SessionModel.fromMap(doc.data(), doc.id, patientId);
    }).toList();
  }
}
