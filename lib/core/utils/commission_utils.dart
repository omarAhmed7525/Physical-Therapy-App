import 'package:physical_therapy/models/session_model.dart';

/// Mutation type for commission session counting.
enum CommissionMutationType { add, update, delete }

/// Pure function to compute the new `commissionSessionsCount` after a session mutation.
///
/// Rules:
/// - `target` is the patient's `commissionSessionsTarget` (default 3, must be >= 1).
/// - On `add`: if `newStatus == completed` and `currentCount < target`, increment by 1.
/// - On `update`:
///   - `completed` -> non-completed: if `0 < currentCount < target`, decrement by 1.
///   - non-completed -> `completed`: if `currentCount < target`, increment by 1.
/// - On `delete`: if `deletedStatus == completed` and `0 < currentCount < target`, decrement by 1.
/// - If `currentCount >= target` (already due), it is never incremented or decremented here.
int computeNextCommissionCount({
  required int currentCount,
  required int target,
  required CommissionMutationType mutationType,
  SessionStatus? oldStatus,
  SessionStatus? newStatus,
  SessionStatus? deletedStatus,
}) {
  final safeTarget = target < 1 ? 1 : target;
  int newCount = currentCount;

  switch (mutationType) {
    case CommissionMutationType.add:
      if (newStatus == SessionStatus.completed && currentCount < safeTarget) {
        newCount = currentCount + 1;
      }
      break;

    case CommissionMutationType.update:
      if (oldStatus == SessionStatus.completed &&
          newStatus != SessionStatus.completed) {
        if (currentCount > 0 && currentCount < safeTarget) {
          newCount = currentCount - 1;
        }
      } else if (oldStatus != SessionStatus.completed &&
          newStatus == SessionStatus.completed) {
        if (currentCount < safeTarget) {
          newCount = currentCount + 1;
        }
      }
      break;

    case CommissionMutationType.delete:
      if (deletedStatus == SessionStatus.completed) {
        if (currentCount > 0 && currentCount < safeTarget) {
          newCount = currentCount - 1;
        }
      }
      break;
  }

  return newCount;
}
