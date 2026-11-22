import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:physical_therapy/core/services/firebase_service.dart';
import 'package:physical_therapy/core/utils/legacy_time_parser.dart';

/// Service responsible for migrating legacy single-user data to the new
/// user-scoped flat structure:
///
/// `patients/{pid}` -> `users/{uid}/patients/{pid}`
/// `patients/{pid}/sessions/{sid}` -> `users/{uid}/sessions/{sid}`
/// `patients/{pid}/commissionHistory/{id}` -> `users/{uid}/commissionHistory/{id}`
///
/// Rules:
/// - Copy only, NEVER delete or modify legacy data.
/// - Same document IDs (idempotent).
/// - Batches of <= 400 ops.
/// - Sessions: add `patientId`, convert time to full `date`, add `durationMinutes: 60`,
///   add `legacyTimeText: <original time string>`, remove `time`.
/// - Commissions: add `patientId`, add `patientName` from patient doc if missing.
/// - Verification: legacy counts == new counts. Only if match, write `users/{uid}/meta/migration`.
class MigrationService {
  final FirebaseService _firebaseService = FirebaseService.instance;

  /// Checks if migration has already been completed for the current user.
  Future<bool> isMigrationDone() async {
    final doc = await _firebaseService.migrationMetaDoc.get();
    if (!doc.exists || doc.data() == null) return false;
    return doc.data()!['done'] == true;
  }

  /// Performs the one-time migration with progress callback.
  Future<void> runMigration({
    required void Function(String message, double progress) onProgress,
  }) async {
    final uid = _firebaseService.currentUid;
    onProgress('جاري قراءة البيانات السابقة...', 0.1);

    // 1. Read all legacy patients
    final legacyPatientsSnapshot =
        await _firebaseService.legacyPatientsCollection.get();
    final legacyPatients = legacyPatientsSnapshot.docs;

    int totalLegacySessionsCount = 0;
    int totalLegacyCommissionsCount = 0;
    int unparsedTimesCount = 0;

    // Collect all data in memory first
    final List<Map<String, dynamic>> newPatients = [];
    final List<Map<String, dynamic>> newSessions = [];
    final List<Map<String, dynamic>> newCommissions = [];

    onProgress('جاري معالجة بيانات المرضى والجلسات...', 0.2);

    for (int i = 0; i < legacyPatients.length; i++) {
      final pDoc = legacyPatients[i];
      final pid = pDoc.id;
      final pData = Map<String, dynamic>.from(pDoc.data());

      newPatients.add({
        'id': pid,
        'data': pData,
      });

      final patientName = (pData['name'] as String?) ?? '';

      // Read subcollection sessions
      final sSnapshot =
          await _firebaseService.legacySessionsCollection(pid).get();
      totalLegacySessionsCount += sSnapshot.docs.length;

      for (final sDoc in sSnapshot.docs) {
        final sid = sDoc.id;
        final sData = Map<String, dynamic>.from(sDoc.data());

        final originalDateTimestamp = sData['date'] as Timestamp?;
        final originalDate = originalDateTimestamp?.toDate() ?? DateTime.now();
        final originalTimeText = (sData['time'] as String?) ?? '';

        DateTime fullDate = originalDate;
        if (originalTimeText.isNotEmpty) {
          final combined = combineLegacyDateAndTime(originalDate, originalTimeText);
          if (combined != null) {
            fullDate = combined;
          } else {
            unparsedTimesCount++;
          }
        }

        // Construct new session map:
        // copy fields, add patientId, converted date, durationMinutes: 60, legacyTimeText
        // do NOT write old 'time'
        final Map<String, dynamic> convertedSession = {
          'patientId': pid,
          'date': Timestamp.fromDate(fullDate),
          'durationMinutes': (sData['durationMinutes'] as num?)?.toInt() ?? 60,
          'price': (sData['price'] as num?)?.toDouble() ?? 0.0,
          'paidAmount': (sData['paidAmount'] as num?)?.toDouble() ?? 0.0,
          'remainingAmount': (sData['remainingAmount'] as num?)?.toDouble() ?? 0.0,
          'status': sData['status'] ?? 'completed',
          'notes': sData['notes'] ?? '',
          'legacyTimeText': originalTimeText,
        };

        newSessions.add({
          'id': sid,
          'data': convertedSession,
        });
      }

      // Read subcollection commissionHistory
      final cSnapshot =
          await _firebaseService.legacyCommissionHistoryCollection(pid).get();
      totalLegacyCommissionsCount += cSnapshot.docs.length;

      for (final cDoc in cSnapshot.docs) {
        final cid = cDoc.id;
        final cData = Map<String, dynamic>.from(cDoc.data());

        final commissionPatientName =
            (cData['patientName'] as String?)?.isNotEmpty == true
                ? cData['patientName'] as String
                : patientName;

        final Map<String, dynamic> convertedCommission = {
          'patientId': pid,
          'patientName': commissionPatientName,
          'amount': (cData['amount'] as num?)?.toDouble() ?? 0.0,
          'paidAt': cData['paidAt'] ?? FieldValue.serverTimestamp(),
        };

        newCommissions.add({
          'id': cid,
          'data': convertedCommission,
        });
      }

      final progress = 0.2 + (0.4 * (i + 1) / (legacyPatients.isEmpty ? 1 : legacyPatients.length));
      onProgress('تمت قراءة ${i + 1} من ${legacyPatients.length} مريض...', progress);
    }

    // 2. Write everything into users/{uid}/... using chunked batches (<= 400 ops)
    onProgress('جاري كتابة البيانات في الحساب الجديد...', 0.6);

    // List of write operations
    final List<void Function(WriteBatch batch)> writes = [];

    // Patients writes
    for (final p in newPatients) {
      writes.add((batch) {
        final ref = _firebaseService.patientDoc(p['id'] as String);
        batch.set(ref, p['data'] as Map<String, dynamic>, SetOptions(merge: true));
      });
    }

    // Sessions writes
    for (final s in newSessions) {
      writes.add((batch) {
        final ref = _firebaseService.sessionDoc(s['id'] as String);
        batch.set(ref, s['data'] as Map<String, dynamic>, SetOptions(merge: true));
      });
    }

    // Commission writes
    for (final c in newCommissions) {
      writes.add((batch) {
        final ref = _firebaseService.commissionHistoryDoc(c['id'] as String);
        batch.set(ref, c['data'] as Map<String, dynamic>, SetOptions(merge: true));
      });
    }

    const chunkSize = 400;
    for (int i = 0; i < writes.length; i += chunkSize) {
      final end = (i + chunkSize < writes.length) ? i + chunkSize : writes.length;
      final chunk = writes.sublist(i, end);

      final batch = _firebaseService.batch;
      for (final writeOp in chunk) {
        writeOp(batch);
      }
      await batch.commit();

      final writeProgress = 0.6 + (0.3 * end / (writes.isEmpty ? 1 : writes.length));
      onProgress('تم حفظ $end من ${writes.length} عنصر...', writeProgress);
    }

    // 3. Verification step
    onProgress('جاري التحقق من مطابقة البيانات...', 0.92);

    final newPatientsCount =
        (await _firebaseService.patientsCollection.count().get()).count ?? 0;
    final newSessionsCount =
        (await _firebaseService.sessionsCollection.count().get()).count ?? 0;
    final newCommissionsCount =
        (await _firebaseService.commissionHistoryCollection.count().get()).count ?? 0;

    final legacyPatientsCount = legacyPatients.length;

    final matches = newPatientsCount == legacyPatientsCount &&
        newSessionsCount == totalLegacySessionsCount &&
        newCommissionsCount == totalLegacyCommissionsCount;

    if (!matches) {
      throw StateError(
        'عدم تطابق في أعداد البيانات بعد النقل: '
        'مرضى: $newPatientsCount/$legacyPatientsCount، '
        'جلسات: $newSessionsCount/$totalLegacySessionsCount، '
        'عمولات: $newCommissionsCount/$totalLegacyCommissionsCount',
      );
    }

    // 4. Mark migration as done
    onProgress('تم الانتهاء بنجاح!', 1.0);
    await _firebaseService.migrationMetaDoc.set({
      'done': true,
      'migratedAt': FieldValue.serverTimestamp(),
      'counts': {
        'patients': newPatientsCount,
        'sessions': newSessionsCount,
        'commissionHistory': newCommissionsCount,
      },
      'unparsedTimes': unparsedTimesCount,
      'uid': uid,
    });
  }
}
