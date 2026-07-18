import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:physical_therapy/app/routes.dart';
import 'package:physical_therapy/models/session_model.dart';
import 'package:physical_therapy/core/constants/app_colors.dart';

class SessionCard extends StatelessWidget {
  final SessionModel session;
  final String? patientName; // Optional, if we display it in a general sessions list

  const SessionCard({
    super.key,
    required this.session,
    this.patientName,
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
    final isDark = theme.brightness == Brightness.dark;

    final statusColor = _getStatusColor(session.status, theme);
    final remainingColor = session.remainingAmount > 0
        ? (isDark ? AppColors.darkError : AppColors.lightError)
        : (isDark ? AppColors.darkSuccess : AppColors.lightSuccess);

    final formattedDate = DateFormat('yyyy/MM/dd').format(session.date);

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_month,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formattedDate,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        session.time,
                        style: textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor.withOpacity(0.5)),
                    ),
                    child: Text(
                      session.status.arabicLabel,
                      style: textTheme.labelSmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              if (patientName != null) ...[
                const SizedBox(height: 8),
                Text(
                  'المريض: $patientName',
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Divider(color: theme.dividerColor.withOpacity(0.3)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildPaymentInfo(
                    context,
                    'السعر الإجمالي',
                    '${session.price.toStringAsFixed(0)} ج.م',
                    theme.colorScheme.onSurface,
                  ),
                  _buildPaymentInfo(
                    context,
                    'المدفوع',
                    '${session.paidAmount.toStringAsFixed(0)} ج.م',
                    isDark ? AppColors.darkSuccess : AppColors.lightSuccess,
                  ),
                  _buildPaymentInfo(
                    context,
                    'المتبقي',
                    '${session.remainingAmount.toStringAsFixed(0)} ج.م',
                    remainingColor,
                    isBold: session.remainingAmount > 0,
                  ),
                ],
              ),
              if (session.notes.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.dividerColor.withOpacity(0.5),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.note,
                        size: 16,
                        color: theme.colorScheme.secondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          session.notes,
                          style: textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentInfo(
    BuildContext context,
    String label,
    String value,
    Color valueColor, {
    bool isBold = false,
  }) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: textTheme.bodyMedium?.copyWith(
            color: valueColor,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
