import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:physical_therapy/core/utils/conflict_utils.dart';
import 'package:physical_therapy/core/utils/debt_calculator.dart';
import 'package:physical_therapy/core/utils/legacy_time_parser.dart';
import 'package:physical_therapy/core/utils/maps_route_builder.dart';
import 'package:physical_therapy/core/utils/phone_utils.dart';
import 'package:physical_therapy/core/utils/plan_calculator.dart';
import 'package:physical_therapy/models/debt_payment_model.dart';
import 'package:physical_therapy/models/patient_model.dart';
import 'package:physical_therapy/models/session_model.dart';

void main() {
  group('LegacyTimeParser & combineLegacyDateAndTime', () {
    final baseDate = DateTime(2026, 6, 15);

    test('parses ASCII AM/PM times correctly', () {
      final t1 = combineLegacyDateAndTime(baseDate, '10:30 AM');
      expect(t1, DateTime(2026, 6, 15, 10, 30));

      final t2 = combineLegacyDateAndTime(baseDate, '03:15 PM');
      expect(t2, DateTime(2026, 6, 15, 15, 15));

      final t12am = combineLegacyDateAndTime(baseDate, '12:00 AM');
      expect(t12am, DateTime(2026, 6, 15, 0, 0));

      final t12pm = combineLegacyDateAndTime(baseDate, '12:45 PM');
      expect(t12pm, DateTime(2026, 6, 15, 12, 45));
    });

    test('parses Arabic markers and Arabic-Indic / Persian digits', () {
      final t1 = combineLegacyDateAndTime(baseDate, '١٠:٣٠ ص');
      expect(t1, DateTime(2026, 6, 15, 10, 30));

      final t2 = combineLegacyDateAndTime(baseDate, '٠٤:٢٠ م');
      expect(t2, DateTime(2026, 6, 15, 16, 20));

      // With bidirectional / zero-width characters
      final t3 = combineLegacyDateAndTime(baseDate, '\u200E10:30 \u200Fص');
      expect(t3, DateTime(2026, 6, 15, 10, 30));
    });

    test('parses 24-hour time strings', () {
      final t24 = combineLegacyDateAndTime(baseDate, '18:45');
      expect(t24, DateTime(2026, 6, 15, 18, 45));
    });

    test('returns null for invalid time strings', () {
      expect(combineLegacyDateAndTime(baseDate, ''), isNull);
      expect(combineLegacyDateAndTime(baseDate, 'invalid text'), isNull);
      expect(combineLegacyDateAndTime(baseDate, '25:00'), isNull);
      expect(combineLegacyDateAndTime(baseDate, '10:70'), isNull);
    });
  });

  group('ConflictUtils', () {
    final existing = [
      SessionModel(
        id: 's1',
        patientId: 'p1',
        date: DateTime(2026, 6, 15, 10, 0),
        durationMinutes: 60,
        price: 200,
        paidAmount: 200,
        remainingAmount: 0,
        status: SessionStatus.scheduled,
        notes: '',
      ),
      SessionModel(
        id: 's2',
        patientId: 'p2',
        date: DateTime(2026, 6, 15, 12, 0),
        durationMinutes: 60,
        price: 200,
        paidAmount: 200,
        remainingAmount: 0,
        status: SessionStatus.completed,
        notes: '',
      ),
      SessionModel(
        id: 's3',
        patientId: 'p3',
        date: DateTime(2026, 6, 15, 14, 0),
        durationMinutes: 60,
        price: 200,
        paidAmount: 200,
        remainingAmount: 0,
        status: SessionStatus.cancelled,
        notes: '',
      ),
    ];

    test('detects overlapping scheduled or completed sessions', () {
      // Overlaps with s1 (10:00 - 11:00)
      final conflict1 = ConflictUtils.findConflict(
        start: DateTime(2026, 6, 15, 10, 30),
        durationMinutes: 60,
        status: SessionStatus.scheduled,
        existingSessions: existing,
      );
      expect(conflict1?.id, 's1');

      // Overlaps with s2 (12:00 - 13:00)
      final conflict2 = ConflictUtils.findConflict(
        start: DateTime(2026, 6, 15, 11, 30),
        durationMinutes: 60,
        status: SessionStatus.completed,
        existingSessions: existing,
      );
      expect(conflict2?.id, 's2');
    });

    test('touching boundaries do not conflict', () {
      final noConflict = ConflictUtils.findConflict(
        start: DateTime(2026, 6, 15, 11, 0),
        durationMinutes: 60,
        status: SessionStatus.scheduled,
        existingSessions: existing,
      );
      expect(noConflict, isNull);
    });

    test('cancelled or postponed sessions never block or conflict', () {
      // Proposed session is cancelled -> never conflicts
      final c1 = ConflictUtils.findConflict(
        start: DateTime(2026, 6, 15, 10, 30),
        durationMinutes: 60,
        status: SessionStatus.cancelled,
        existingSessions: existing,
      );
      expect(c1, isNull);

      // Proposed overlaps with cancelled s3 (14:00 - 15:00) -> does not conflict
      final c2 = ConflictUtils.findConflict(
        start: DateTime(2026, 6, 15, 14, 15),
        durationMinutes: 45,
        status: SessionStatus.scheduled,
        existingSessions: existing,
      );
      expect(c2, isNull);
    });

    test('excludeSessionId excludes self when editing', () {
      final conflict = ConflictUtils.findConflict(
        start: DateTime(2026, 6, 15, 10, 0),
        durationMinutes: 60,
        status: SessionStatus.scheduled,
        existingSessions: existing,
        excludeSessionId: 's1',
      );
      expect(conflict, isNull);
    });
  });

  group('DebtCalculator', () {
    final sessions = [
      SessionModel(
        id: 's1',
        patientId: 'p1',
        date: DateTime(2026, 6, 1),
        price: 200,
        paidAmount: 50,
        remainingAmount: 150,
        status: SessionStatus.completed,
        notes: '',
      ),
      SessionModel(
        id: 's2',
        patientId: 'p1',
        date: DateTime(2026, 6, 10),
        price: 200,
        paidAmount: 100,
        remainingAmount: 100,
        status: SessionStatus.completed,
        notes: '',
      ),
      // Cancelled session should not count toward debt
      SessionModel(
        id: 's3',
        patientId: 'p1',
        date: DateTime(2026, 6, 15),
        price: 200,
        paidAmount: 0,
        remainingAmount: 200,
        status: SessionStatus.cancelled,
        notes: '',
      ),
    ];

    test('calculates outstanding debt correctly with repayments', () {
      final payments = [
        DebtPaymentModel(
          id: 'pay1',
          patientId: 'p1',
          amount: 100,
          paidAt: DateTime(2026, 6, 12),
        ),
      ];

      // Total remaining completed = 150 + 100 = 250
      // Total paid = 100
      // Outstanding = 150
      final outstanding = DebtCalculator.calculateOutstandingDebt(
        patientId: 'p1',
        sessions: sessions,
        debtPayments: payments,
      );
      expect(outstanding, 150.0);
    });

    test('outstanding debt never drops below zero', () {
      final overpayments = [
        DebtPaymentModel(
          id: 'pay1',
          patientId: 'p1',
          amount: 500,
          paidAt: DateTime(2026, 6, 12),
        ),
      ];

      final outstanding = DebtCalculator.calculateOutstandingDebt(
        patientId: 'p1',
        sessions: sessions,
        debtPayments: overpayments,
      );
      expect(outstanding, 0.0);
    });

    test('incomeForMonth calculates cash basis correctly', () {
      final payments = [
        DebtPaymentModel(
          id: 'pay1',
          patientId: 'p1',
          amount: 75,
          paidAt: DateTime(2026, 6, 20),
        ),
        DebtPaymentModel(
          id: 'pay2',
          patientId: 'p1',
          amount: 50,
          paidAt: DateTime(2026, 7, 1), // Different month
        ),
      ];

      // Sessions in June: s1 paidAmount=50, s2 paidAmount=100 -> 150
      // Debt payment in June: pay1 amount=75 -> 75
      // Total June income = 225
      final incomeJune = incomeForMonth(
        sessions: sessions,
        debtPayments: payments,
        year: 2026,
        month: 6,
      );
      expect(incomeJune, 225.0);
    });
  });

  group('PlanCalculator (Threshold = 1)', () {
    final patientWithPlan = PatientModel(
      id: 'p1',
      name: 'مريض',
      phone: '01000000000',
      address: '',
      medicalNotes: '',
      createdAt: DateTime(2026, 6, 1),
      planTotalSessions: 10,
      planStartDate: DateTime(2026, 6, 1),
    );

    test('calculates used and remaining sessions correctly', () {
      final sessions = [
        // 8 completed sessions in plan window
        for (int i = 0; i < 8; i++)
          SessionModel(
            id: 's$i',
            patientId: 'p1',
            date: DateTime(2026, 6, 2 + i),
            price: 200,
            paidAmount: 200,
            remainingAmount: 0,
            status: SessionStatus.completed,
            notes: '',
          ),
        // One session before plan start (must be ignored)
        SessionModel(
          id: 's_old',
          patientId: 'p1',
          date: DateTime(2026, 5, 20),
          price: 200,
          paidAmount: 200,
          remainingAmount: 0,
          status: SessionStatus.completed,
          notes: '',
        ),
        // One scheduled session (must not count as used)
        SessionModel(
          id: 's_sched',
          patientId: 'p1',
          date: DateTime(2026, 6, 25),
          price: 200,
          paidAmount: 200,
          remainingAmount: 0,
          status: SessionStatus.scheduled,
          notes: '',
        ),
      ];

      final used = PlanCalculator.calculateUsedSessions(
        patient: patientWithPlan,
        sessions: sessions,
      );
      expect(used, 8);

      final remaining = PlanCalculator.calculateRemainingSessions(
        patient: patientWithPlan,
        sessions: sessions,
      );
      expect(remaining, 2);

      // With remaining = 2 and threshold = 1, state should be normal
      expect(
        PlanCalculator.getPlanState(
          patient: patientWithPlan,
          sessions: sessions,
        ),
        PlanState.normal,
      );
    });

    test('triggers PlanState.low only when remaining is exactly 1', () {
      final sessions = [
        for (int i = 0; i < 9; i++)
          SessionModel(
            id: 's$i',
            patientId: 'p1',
            date: DateTime(2026, 6, 2 + i),
            price: 200,
            paidAmount: 200,
            remainingAmount: 0,
            status: SessionStatus.completed,
            notes: '',
          ),
      ];

      final remaining = PlanCalculator.calculateRemainingSessions(
        patient: patientWithPlan,
        sessions: sessions,
      );
      expect(remaining, 1);

      expect(
        PlanCalculator.getPlanState(
          patient: patientWithPlan,
          sessions: sessions,
        ),
        PlanState.low,
      );
    });

    test('triggers PlanState.finished when remaining is 0', () {
      final sessions = [
        for (int i = 0; i < 10; i++)
          SessionModel(
            id: 's$i',
            patientId: 'p1',
            date: DateTime(2026, 6, 2 + i),
            price: 200,
            paidAmount: 200,
            remainingAmount: 0,
            status: SessionStatus.completed,
            notes: '',
          ),
      ];

      final remaining = PlanCalculator.calculateRemainingSessions(
        patient: patientWithPlan,
        sessions: sessions,
      );
      expect(remaining, 0);

      expect(
        PlanCalculator.getPlanState(
          patient: patientWithPlan,
          sessions: sessions,
        ),
        PlanState.finished,
      );
    });
  });

  group('PhoneUtils', () {
    test('normalizes Egyptian numbers correctly', () {
      expect(PhoneUtils.normalizeEgyptPhone('01012345678'), '+201012345678');
      expect(PhoneUtils.normalizeEgyptPhone('+201012345678'), '+201012345678');
      expect(PhoneUtils.normalizeEgyptPhone('00201012345678'), '+201012345678');
      expect(PhoneUtils.normalizeEgyptPhone('010-1234-5678'), '+201012345678');
    });

    test('builds valid WhatsApp URI with encoded message', () {
      final uri = PhoneUtils.buildWhatsAppUri(
        phone: '01012345678',
        message: 'مرحباً بك',
      );
      expect(uri.host, 'wa.me');
      expect(uri.path, '/201012345678');
      expect(uri.queryParameters['text'], 'مرحباً بك');
    });
  });

  group('MapsRouteBuilder', () {
    test('filters and sorts today route stops chronologically', () {
      final p1 = PatientModel(
        id: 'p1',
        name: 'مريض 1',
        phone: '010',
        address: '',
        medicalNotes: '',
        createdAt: DateTime(2026, 6, 1),
        location: const GeoPoint(30.0, 31.0),
      );
      final p2 = PatientModel(
        id: 'p2',
        name: 'مريض 2',
        phone: '011',
        address: '',
        medicalNotes: '',
        createdAt: DateTime(2026, 6, 1),
        location: const GeoPoint(30.1, 31.1),
      );
      final pNoLoc = PatientModel(
        id: 'p3',
        name: 'مريض بدون موقع',
        phone: '012',
        address: '',
        medicalNotes: '',
        createdAt: DateTime(2026, 6, 1),
      );

      final Map<String, PatientModel> map = {'p1': p1, 'p2': p2, 'p3': pNoLoc};

      final sessions = [
        SessionModel(
          id: 's2',
          patientId: 'p2',
          date: DateTime(2026, 6, 15, 14, 0),
          price: 200,
          paidAmount: 200,
          remainingAmount: 0,
          status: SessionStatus.scheduled,
          notes: '',
        ),
        SessionModel(
          id: 's1',
          patientId: 'p1',
          date: DateTime(2026, 6, 15, 10, 0),
          price: 200,
          paidAmount: 200,
          remainingAmount: 0,
          status: SessionStatus.scheduled,
          notes: '',
        ),
        SessionModel(
          id: 's3',
          patientId: 'p3',
          date: DateTime(2026, 6, 15, 12, 0),
          price: 200,
          paidAmount: 200,
          remainingAmount: 0,
          status: SessionStatus.scheduled,
          notes: '',
        ),
      ];

      final stops = MapsRouteBuilder.buildTodayRoute(
        todaySessions: sessions,
        patientsMap: map,
      );

      expect(stops.length, 2);
      expect(stops[0].patient.id, 'p1');
      expect(stops[0].stopNumber, 1);
      expect(stops[1].patient.id, 'p2');
      expect(stops[1].stopNumber, 2);
    });
  });
}
