import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class IncomeCard extends StatelessWidget {
  final double amount;

  const IncomeCard({super.key, required this.amount});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;

    final String arabicMonthName = DateFormat('MMMM', 'ar').format(DateTime.now());

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.primary.withValues(alpha: 0.12)
            : theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(16),
        border: isDark
            ? Border.all(color: theme.colorScheme.primary)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'الدخل الشهري ($arabicMonthName)',
            style: textTheme.titleMedium?.copyWith(
              color: isDark ? theme.colorScheme.primary : theme.colorScheme.onPrimary.withValues(alpha: 0.9),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${amount.toStringAsFixed(0)} ج.م',
            style: textTheme.headlineMedium?.copyWith(
              color: isDark ? theme.colorScheme.onSurface : theme.colorScheme.onPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'إجمالي المدفوعات من الجلسات المكتملة + سداد المديونيات',
            style: textTheme.bodySmall?.copyWith(
              color: isDark
                  ? theme.colorScheme.onSurface.withValues(alpha: 0.5)
                  : theme.colorScheme.onPrimary.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}
