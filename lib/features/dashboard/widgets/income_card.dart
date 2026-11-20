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
        gradient: LinearGradient(
          colors: isDark
              ? [theme.colorScheme.primary.withValues(alpha: 0.15), theme.colorScheme.secondary.withValues(alpha: 0.05)]
              : [theme.colorScheme.primary, theme.colorScheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
        border: isDark
            ? Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3))
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الدخل الشهري ($arabicMonthName)',
                  style: textTheme.titleMedium?.copyWith(
                    color: isDark ? theme.colorScheme.primary : Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${amount.toStringAsFixed(0)} ج.م',
                  style: textTheme.headlineMedium?.copyWith(
                    color: isDark ? Colors.white : Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'إجمالي المدفوعات من الجلسات المكتملة + سداد المديونيات',
                  style: textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? theme.colorScheme.onSurface.withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          CircleAvatar(
            radius: 28,
            backgroundColor: isDark
                ? theme.colorScheme.primary.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.2),
            child: const Icon(
              Icons.account_balance_wallet,
              size: 28,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
