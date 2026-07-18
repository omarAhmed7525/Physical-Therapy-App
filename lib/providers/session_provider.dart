import 'dart:async';
import 'package:flutter/material.dart';
import 'package:physical_therapy/models/session_model.dart';
import 'package:physical_therapy/repositories/session_repository.dart';

class SessionProvider extends ChangeNotifier {
  final SessionRepository _sessionRepository = SessionRepository();

  List<SessionModel> _sessions = [];
  List<SessionModel> _todaySessions = [];
  bool _isLoading = false;
  String? _error;
  StreamSubscription<List<SessionModel>>? _todaySessionsSubscription;
  StreamSubscription<List<SessionModel>>? _allSessionsSubscription;

  List<SessionModel> get sessions => List.unmodifiable(_sessions);

  List<SessionModel> patientSessions(String patientId) =>
      _sessions.where((s) => s.patientId == patientId).toList();

  List<SessionModel> get todaySessions => List.unmodifiable(_todaySessions);
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Business Logic: Monthly income = sum of paidAmount from completed sessions only (in current month)
  double get monthlyIncome {
    final now = DateTime.now();
    return _sessions.where((session) {
      return session.status == SessionStatus.completed &&
          session.date.year == now.year &&
          session.date.month == now.month;
    }).fold(0.0, (sum, session) => sum + session.paidAmount);
  }

  SessionProvider() {
    _listenToTodaySessions();
    _listenToAllSessions();
  }

  /// Listen to today's sessions in real-time for the dashboard
  void _listenToTodaySessions() {
    _todaySessionsSubscription?.cancel();
    _todaySessionsSubscription = _sessionRepository.getTodaySessionsStream().listen(
          (sessionsList) {
        _todaySessions = sessionsList;
        _error = null;
        notifyListeners();
      },
      onError: (err) {
        _error = err.toString();
        notifyListeners();
      },
    );
  }

  /// Listen to all sessions in real-time
  void _listenToAllSessions() {
    _allSessionsSubscription?.cancel();
    _allSessionsSubscription = _sessionRepository.getAllSessionsStream().listen(
          (sessionsList) {
        _sessions = sessionsList;
        _error = null;
        notifyListeners();
      },
      onError: (err) {
        _error = err.toString();
        notifyListeners();
      },
    );
  }

  /// Add a new session under a patient.
  /// Computes remainingAmount securely: `(price - paidAmount).clamp(0, double.infinity)`
  Future<void> addSession({
    required String patientId,
    required DateTime date,
    required String time,
    required double price,
    required double paidAmount,
    required SessionStatus status,
    required String notes,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final remainingAmount = (price - paidAmount).clamp(0.0, double.infinity);

      final newSession = SessionModel(
        id: '', // Firestore auto-generates
        patientId: patientId,
        date: date,
        time: time,
        price: price,
        paidAmount: paidAmount,
        remainingAmount: remainingAmount,
        status: status,
        notes: notes,
      );

      await _sessionRepository.addSession(newSession);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update an existing session.
  /// Computes remainingAmount securely: `(price - paidAmount).clamp(0, double.infinity)`
  Future<void> updateSession(
      SessionModel session, {
        required DateTime date,
        required String time,
        required double price,
        required double paidAmount,
        required SessionStatus status,
        required String notes,
      }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final remainingAmount = (price - paidAmount).clamp(0.0, double.infinity);

      final updatedSession = session.copyWith(
        date: date,
        time: time,
        price: price,
        paidAmount: paidAmount,
        remainingAmount: remainingAmount,
        status: status,
        notes: notes,
      );

      await _sessionRepository.updateSession(updatedSession);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Delete a session.
  Future<void> deleteSession(String patientId, String sessionId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _sessionRepository.deleteSession(patientId, sessionId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _todaySessionsSubscription?.cancel();
    _allSessionsSubscription?.cancel();
    super.dispose();
  }
}























/*import 'dart:async';
import 'package:flutter/material.dart';
import 'package:physical_therapy/models/session_model.dart';
import 'package:physical_therapy/repositories/session_repository.dart';

class SessionProvider extends ChangeNotifier {
  final SessionRepository _sessionRepository = SessionRepository();

  List<SessionModel> _sessions = [];
  //List<SessionModel> _patientSessions = [];
  List<SessionModel> _todaySessions = [];
  bool _isLoading = false;
  String? _error;
  StreamSubscription<List<SessionModel>>? _todaySessionsSubscription;
  StreamSubscription<List<SessionModel>>? _allSessionsSubscription;

  List<SessionModel> get sessions => List.unmodifiable(_sessions);
  List<SessionModel> patientSessions(String patientId) =>
      _sessions.where((s) => s.patientId == patientId).toList();  List<SessionModel> get todaySessions => List.unmodifiable(_todaySessions);
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Business Logic: Monthly income = sum of paidAmount from completed sessions only (in current month)
  double get monthlyIncome {
    final now = DateTime.now();
    return _sessions.where((session) {
      return session.status == SessionStatus.completed &&
          session.date.year == now.year &&
          session.date.month == now.month;
    }).fold(0.0, (sum, session) => sum + session.paidAmount);
  }

  SessionProvider() {
    _listenToTodaySessions();
    _listenToAllSessions();
  }

  /// Listen to today's sessions in real-time for the dashboard
  void _listenToTodaySessions() {
    _todaySessionsSubscription?.cancel();
    _todaySessionsSubscription = _sessionRepository.getTodaySessionsStream().listen(
      (sessionsList) {
        _todaySessions = sessionsList;
        _error = null;
        notifyListeners();
      },
      onError: (err) {
        _error = err.toString();
        notifyListeners();
      },
    );
  }

  /// Listen to all sessions in real-time
  void _listenToAllSessions() {
    _allSessionsSubscription?.cancel();
    _allSessionsSubscription = _sessionRepository.getAllSessionsStream().listen(
      (sessionsList) {
        _sessions = sessionsList;
        _error = null;
        notifyListeners();
      },
      onError: (err) {
        _error = err.toString();
        notifyListeners();
      },
    );
  }

  /// Fetch sessions for a specific patient (for details view)
  Future<void> fetchSessionsForPatient(String patientId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _patientSessions = await _sessionRepository.fetchSessionsForPatient(patientId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Add a new session under a patient.
  /// Computes remainingAmount securely: `(price - paidAmount).clamp(0, double.infinity)`
  Future<void> addSession({
    required String patientId,
    required DateTime date,
    required String time,
    required double price,
    required double paidAmount,
    required SessionStatus status,
    required String notes,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final remainingAmount = (price - paidAmount).clamp(0.0, double.infinity);

      final newSession = SessionModel(
        id: '', // Firestore auto-generates
        patientId: patientId,
        date: date,
        time: time,
        price: price,
        paidAmount: paidAmount,
        remainingAmount: remainingAmount,
        status: status,
        notes: notes,
      );

      await _sessionRepository.addSession(newSession);
      // Refresh local patient sessions list after addition
      await _sessionRepository.addSession(newSession);
      _isLoading = false;
      notifyListeners();    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update an existing session.
  /// Computes remainingAmount securely: `(price - paidAmount).clamp(0, double.infinity)`
  Future<void> updateSession(
    SessionModel session, {
    required DateTime date,
    required String time,
    required double price,
    required double paidAmount,
    required SessionStatus status,
    required String notes,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final remainingAmount = (price - paidAmount).clamp(0.0, double.infinity);

      final updatedSession = session.copyWith(
        date: date,
        time: time,
        price: price,
        paidAmount: paidAmount,
        remainingAmount: remainingAmount,
        status: status,
        notes: notes,
      );

      await _sessionRepository.updateSession(updatedSession);
      // Refresh local patient sessions list after update
      await fetchSessionsForPatient(session.patientId);
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Delete a session.
  Future<void> deleteSession(String patientId, String sessionId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _sessionRepository.deleteSession(patientId, sessionId);
      // Refresh local patient sessions list after deletion
      await _sessionRepository.addSession(newSession);
      _isLoading = false;
      notifyListeners();    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _todaySessionsSubscription?.cancel();
    _allSessionsSubscription?.cancel();
    super.dispose();
  }
}
*/