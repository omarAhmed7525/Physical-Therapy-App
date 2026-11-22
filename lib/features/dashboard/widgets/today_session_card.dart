import 'package:flutter/material.dart';
import 'package:physical_therapy/core/constants/app_colors.dart';
import 'package:physical_therapy/core/utils/date_helper.dart';
import 'package:physical_therapy/core/utils/phone_utils.dart';
import 'package:physical_therapy/models/session_model.dart';

class TodaySessionCard extends StatelessWidget {
  final SessionModel session;
  final String patientName;
  final String? patientPhone;
  final VoidCallback onCallPressed;

  const TodaySessionCard({
    super.key,
    required this.session,
    required this.patientName,
    this.patientPhone,
    required this.onCallPressed,
  });

  Color _getStatusColor(SessionStatus status, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    switch (status) {
      case SessionStatus.scheduled:
        return theme.colorScheme.primary;
      case SessionStatus.completed:
        return isDark ? AppColors.darkSuccess : AppColors.lightSuccess;
      case SessionStatus.postponed:
        return isDark ? AppColors.darkWarning : AppColors.lightWarning;
      case SessionStatus.cancelled:
        return isDark ? AppColors.darkError : AppColors.lightError;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    final statusColor = _getStatusColor(session.status, theme);

    return Card(
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            '/sessions/edit',
            arguments: session,
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // ── Time indicator ────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Text(
                  DateHelper.formatTime(session.date),
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // ── Patient Info & Status ──────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patientName,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            session.status.arabicLabel,
                            style: textTheme.bodySmall?.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (session.remainingAmount > 0)
                          Text(
                            'متبقي: ${session.remainingAmount.toStringAsFixed(0)} ج.م',
                            style: textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? AppColors.darkError
                                  : AppColors.lightError,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Quick Actions ──────────────────────────────────────────────
              if (patientPhone != null && patientPhone!.isNotEmpty) ...[
                IconButton.filledTonal(
                  onPressed: () {
                    final message = 'مرحباً، تذكير بموعد جلستك اليوم الساعة ${DateHelper.formatTime(session.date)}';
                    PhoneUtils.launchWhatsApp(
                      phone: patientPhone!,
                      message: message,
                    );
                  },
                  icon: const Icon(Icons.chat),
                  color: theme.colorScheme.primary,
                  tooltip: 'واتساب',
                ),
                const SizedBox(width: 8),
              ],
              IconButton.filledTonal(
                onPressed: onCallPressed,
                icon: const Icon(Icons.phone),
                color: theme.colorScheme.primary,
                tooltip: 'اتصال',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
