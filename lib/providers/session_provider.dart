import 'dart:async';
import 'package:flutter/material.dart';
import 'package:physical_therapy/core/utils/conflict_utils.dart';
import 'package:physical_therapy/core/utils/date_helper.dart';
import 'package:physical_therapy/models/session_model.dart';
import 'package:physical_therapy/repositories/session_repository.dart';
import 'package:physical_therapy/repositories/patient_repository.dart';

enum SessionMutationType { add, update, delete }

class SessionProvider extends ChangeNotifier {
  final SessionRepository _sessionRepository = SessionRepository();
  final PatientRepository _patientRepository;

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

  SessionProvider({PatientRepository? patientRepository})
      : _patientRepository = patientRepository ?? PatientRepository() {
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

  /// Add a new session under current user.
  /// Checks for conflicts (scheduled or completed).
  /// Computes remainingAmount securely: `(price - paidAmount).clamp(0, double.infinity)`
  Future<String?> addSession({
    required String patientId,
    required DateTime date,
    int durationMinutes = 60,
    required double price,
    required double paidAmount,
    required SessionStatus status,
    required String notes,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Conflict check
      final conflict = ConflictUtils.findConflict(
        start: date,
        durationMinutes: durationMinutes,
        status: status,
        existingSessions: _sessions,
      );

      if (conflict != null) {
        final conflictPatient = await _patientRepository.getPatientById(conflict.patientId);
        final patientName = conflictPatient?.name ?? 'مريض آخر';
        final timeStr = DateHelper.formatTime(conflict.date);
        throw Exception('يوجد تعارض مع جلسة المريض $patientName الساعة $timeStr');
      }

      final remainingAmount = (price - paidAmount).clamp(0.0, double.infinity);

      final newSession = SessionModel(
        id: '', // Firestore auto-generates
        patientId: patientId,
        date: date,
        durationMinutes: durationMinutes,
        price: price,
        paidAmount: paidAmount,
        remainingAmount: remainingAmount,
        status: status,
        notes: notes,
      );

      final newId = await _sessionRepository.addSession(newSession);

      // Update patient commission count if enabled
      await _updatePatientCommissionOnMutation(
        patientId: patientId,
        mutationType: SessionMutationType.add,
        newStatus: status,
      );

      _isLoading = false;
      notifyListeners();
      return newId;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Update an existing session.
  /// Checks for conflicts, excluding self.
  /// Computes remainingAmount securely: `(price - paidAmount).clamp(0, double.infinity)`
  Future<void> updateSession(
    SessionModel session, {
    required DateTime date,
    int durationMinutes = 60,
    required double price,
    required double paidAmount,
    required SessionStatus status,
    required String notes,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Conflict check (exclude self)
      final conflict = ConflictUtils.findConflict(
        start: date,
        durationMinutes: durationMinutes,
        status: status,
        existingSessions: _sessions,
        excludeSessionId: session.id,
      );

      if (conflict != null) {
        final conflictPatient = await _patientRepository.getPatientById(conflict.patientId);
        final patientName = conflictPatient?.name ?? 'مريض آخر';
        final timeStr = DateHelper.formatTime(conflict.date);
        throw Exception('يوجد تعارض مع جلسة المريض $patientName الساعة $timeStr');
      }

      final remainingAmount = (price - paidAmount).clamp(0.0, double.infinity);
      final oldStatus = session.status;

      final updatedSession = session.copyWith(
        date: date,
        durationMinutes: durationMinutes,
        price: price,
        paidAmount: paidAmount,
        remainingAmount: remainingAmount,
        status: status,
        notes: notes,
      );

      await _sessionRepository.updateSession(updatedSession);

      // Update patient commission count if enabled
      await _updatePatientCommissionOnMutation(
        patientId: session.patientId,
        mutationType: SessionMutationType.update,
        oldStatus: oldStatus,
        newStatus: status,
      );

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
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
      final sessionToDelete = _sessions.cast<SessionModel?>().firstWhere(
            (s) => s?.id == sessionId,
            orElse: () => null,
          );
      final deletedStatus = sessionToDelete?.status;

      await _sessionRepository.deleteSession(patientId, sessionId);

      if (deletedStatus != null) {
        await _updatePatientCommissionOnMutation(
          patientId: patientId,
          mutationType: SessionMutationType.delete,
          deletedStatus: deletedStatus,
        );
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Helper logic to track and adjust commission sessions count.
  /// Isolated and well-commented to ensure correctness across session mutations.
  Future<void> _updatePatientCommissionOnMutation({
    required String patientId,
    required SessionMutationType mutationType,
    SessionStatus? oldStatus,
    SessionStatus? newStatus,
    SessionStatus? deletedStatus,
  }) async {
    try {
      final patient = await _patientRepository.getPatientById(patientId);
      if (patient == null || !patient.commissionEnabled) return;

      final currentCount = patient.commissionSessionsCount;
      int newCount = currentCount;

      switch (mutationType) {
        case SessionMutationType.add:
          // Increment if the added session is completed, and we haven't reached the limit of 3.
          if (newStatus == SessionStatus.completed && currentCount < 3) {
            newCount = currentCount + 1;
          }
          break;

        case SessionMutationType.update:
          // Status changed FROM completed TO something else (scheduled/postponed/cancelled).
          if (oldStatus == SessionStatus.completed && newStatus != SessionStatus.completed) {
            // Only adjust if not already due (i.e. count is 1 or 2).
            if (currentCount == 1 || currentCount == 2) {
              newCount = currentCount - 1;
            }
          }
          // Status changed FROM something else TO completed.
          else if (oldStatus != SessionStatus.completed && newStatus == SessionStatus.completed) {
            // Increment up to the cap of 3.
            if (currentCount < 3) {
              newCount = currentCount + 1;
            }
          }
          break;

        case SessionMutationType.delete:
          // Decrement if the deleted session was completed.
          if (deletedStatus == SessionStatus.completed) {
            // Only adjust if not already due (i.e. count is 1 or 2).
            if (currentCount == 1 || currentCount == 2) {
              newCount = currentCount - 1;
            }
          }
          break;
      }

      // If the count changed, update the patient document.
      if (newCount != currentCount) {
        final updatedPatient = patient.copyWith(commissionSessionsCount: newCount);
        await _patientRepository.updatePatient(updatedPatient);
      }
    } catch (e) {
      debugPrint('Error updating patient commission count: $e');
    }
  }

  @override
  void dispose() {
    _todaySessionsSubscription?.cancel();
    _allSessionsSubscription?.cancel();
    super.dispose();
  }
}
