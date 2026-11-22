import 'package:physical_therapy/core/services/firebase_service.dart';
import 'package:physical_therapy/models/session_model.dart';

class SessionRepository {
  final FirebaseService _firebaseService = FirebaseService.instance;

  /// Fetch all sessions for a specific patient.
  Future<List<SessionModel>> fetchSessionsForPatient(String patientId) async {
    final snapshot = await _firebaseService.sessionsForPatient(patientId).get();

    return snapshot.docs.map((doc) {
      return SessionModel.fromMap(doc.data(), doc.id, patientId);
    }).toList();
  }

  /// Add a new session under `users/{uid}/sessions`.
  Future<String> addSession(SessionModel session) async {
    final docRef = await _firebaseService.sessionsCollection.add(session.toMap());
    return docRef.id;
  }

  /// Update an existing session under `users/{uid}/sessions/{id}`.
  Future<void> updateSession(SessionModel session) async {
    await _firebaseService.sessionDoc(session.id).update(session.toMap());
  }

  /// Delete a session.
  Future<void> deleteSession(String patientId, String sessionId) async {
    await _firebaseService.sessionDoc(sessionId).delete();
  }

  /// Stream of today's sessions for the current user.
  Stream<List<SessionModel>> getTodaySessionsStream() {
    return _firebaseService.todaySessionsQuery().snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return SessionModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  /// Stream of ALL sessions for the current user.
  Stream<List<SessionModel>> getAllSessionsStream() {
    return _firebaseService.allSessionsQuery().snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return SessionModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  /// Fetch all sessions within a date range across current user's sessions.
  Future<List<SessionModel>> fetchAllSessionsByDateRange(
    DateTime from,
    DateTime to,
  ) async {
    final snapshot = await _firebaseService
        .sessionsByDateRange(from: from, to: to)
        .get();

    return snapshot.docs.map((doc) {
      return SessionModel.fromMap(doc.data(), doc.id);
    }).toList();
  }
}
