import 'package:flutter/material.dart';
import 'package:physical_therapy/app/routes.dart';
import 'package:physical_therapy/models/session_model.dart';
import 'package:physical_therapy/core/constants/app_colors.dart';

class TodaySessionCard extends StatelessWidget {
  final SessionModel session;
  final String patientName;
  final VoidCallback onCallPressed;

  const TodaySessionCard({
    super.key,
    required this.session,
    required this.patientName,
    required this.onCallPressed,
  });

  Color _getStatusColor(SessionStatus status, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    switch (status) {
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
            AppRoutes.editSession,
            arguments: session,
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // ── Time & Icon indicator ──────────────────────────────────────
              Column(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                    child: Icon(
                      Icons.access_time_filled,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    session.time,
                    style: textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: statusColor.withOpacity(0.4)),
                          ),
                          child: Text(
                            session.status.arabicLabel,
                            style: textTheme.labelSmall?.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${session.price.toStringAsFixed(0)} ج.م',
                          style: textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Action Buttons ─────────────────────────────────────────────
              IconButton(
                icon: Icon(
                  Icons.phone_in_talk,
                  color: theme.colorScheme.secondary,
                ),
                onPressed: onCallPressed,
                tooltip: 'اتصال بالمريض',
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurface.withOpacity(0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
