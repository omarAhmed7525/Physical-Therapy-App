import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:physical_therapy/core/constants/app_colors.dart';
import 'package:physical_therapy/core/utils/date_helper.dart';
import 'package:physical_therapy/core/utils/phone_utils.dart';
import 'package:physical_therapy/models/session_model.dart';

class SessionCard extends StatelessWidget {
  final SessionModel session;
  final String? patientName; // Optional, if we display it in a general sessions list
  final String? patientPhone; // Optional, for WhatsApp action (C1)

  const SessionCard({
    super.key,
    required this.session,
    this.patientName,
    this.patientPhone,
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
            '/sessions/edit',
            arguments: session,
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header Row: Date/Time & Status badge ───────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
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
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateHelper.formatTime(session.date),
                        style: textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (patientPhone != null && patientPhone!.isNotEmpty)
                        IconButton(
                          icon: Icon(
                            Icons.chat,
                            size: 20,
                            color: theme.colorScheme.primary,
                          ),
                          tooltip: 'إرسال واتساب',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            final formattedDate = DateFormat('yyyy/MM/dd').format(session.date);
                            final message = 'مرحباً، تذكير بموعد جلستك يوم $formattedDate';
                            PhoneUtils.launchWhatsApp(
                              phone: patientPhone!,
                              message: message,
                            );
                          },
                        ),
                      if (patientPhone != null && patientPhone!.isNotEmpty)
                        const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          session.status.arabicLabel,
                          style: textTheme.bodySmall?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── Patient Name (if available) ────────────────────────────────
              if (patientName != null && patientName!.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(
                      Icons.person,
                      size: 16,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      patientName!,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              const Divider(height: 1),
              const SizedBox(height: 12),

              // ── Financials Row ─────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildFinancialItem(
                    context,
                    'السعر',
                    '${session.price.toStringAsFixed(0)} ج.م',
                    theme.colorScheme.onSurface,
                  ),
                  _buildFinancialItem(
                    context,
                    'المدفوع',
                    '${session.paidAmount.toStringAsFixed(0)} ج.م',
                    isDark ? AppColors.darkSuccess : AppColors.lightSuccess,
                  ),
                  _buildFinancialItem(
                    context,
                    'المتبقي',
                    '${session.remainingAmount.toStringAsFixed(0)} ج.م',
                    remainingColor,
                  ),
                ],
              ),

              // ── Notes Preview (if any) ─────────────────────────────────────
              if (session.notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.notes,
                        size: 14,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          session.notes,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
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

  Widget _buildFinancialItem(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
