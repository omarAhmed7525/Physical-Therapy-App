import 'package:physical_therapy/models/session_model.dart';

/// Pure utility functions for detecting session time conflicts.
class ConflictUtils {
  ConflictUtils._();

  /// Checks if two sessions overlap in time.
  ///
  /// Two sessions conflict if `newStart < otherEnd && otherStart < newEnd`,
  /// where end = `date + durationMinutes`. Touching boundaries are allowed.
  static bool doSessionsOverlap({
    required DateTime startA,
    required int durationA,
    required DateTime startB,
    required int durationB,
  }) {
    final endA = startA.add(Duration(minutes: durationA));
    final endB = startB.add(Duration(minutes: durationB));

    return startA.isBefore(endB) && startB.isBefore(endA);
  }

  /// Checks if a proposed session conflicts with any existing sessions in [existingSessions].
  ///
  /// Rules:
  /// - Only sessions with status `scheduled` or `completed` occupy a slot;
  ///   `postponed` or `cancelled` never block.
  /// - A session being saved with status `postponed` or `cancelled` is not checked (returns null).
  /// - When editing, [excludeSessionId] excludes the session itself.
  /// - Returns the conflicting [SessionModel] if a conflict exists, or `null` if none.
  static SessionModel? findConflict({
    required DateTime start,
    required int durationMinutes,
    required SessionStatus status,
    required List<SessionModel> existingSessions,
    String? excludeSessionId,
  }) {
    // If the proposed session is postponed or cancelled, it never blocks and cannot conflict
    if (status == SessionStatus.postponed || status == SessionStatus.cancelled) {
      return null;
    }

    for (final other in existingSessions) {
      if (excludeSessionId != null && other.id == excludeSessionId) {
        continue;
      }
      // Only scheduled or completed occupy a slot
      if (other.status != SessionStatus.scheduled &&
          other.status != SessionStatus.completed) {
        continue;
      }

      if (doSessionsOverlap(
        startA: start,
        durationA: durationMinutes,
        startB: other.date,
        durationB: other.durationMinutes,
      )) {
        return other;
      }
    }

    return null;
  }
}
