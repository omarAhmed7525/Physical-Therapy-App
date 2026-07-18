import 'package:flutter/material.dart';
import 'package:physical_therapy/core/utils/date_helper.dart';
import 'package:physical_therapy/features/sessions/widgets/session_card.dart';
import 'package:physical_therapy/models/session_model.dart';
import 'package:physical_therapy/providers/patient_provider.dart';
import 'package:physical_therapy/providers/session_provider.dart';
import 'package:provider/provider.dart';

class ReportsView extends StatefulWidget {
  const ReportsView({super.key});

  @override
  State<ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends State<ReportsView> {
  late int _selectedMonth;
  late int _selectedYear;

  final List<int> _yearsList = [
    DateTime.now().year - 1,
    DateTime.now().year,
    DateTime.now().year + 1,
  ];

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime.now().month;
    _selectedYear = DateTime.now().year;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;

    final sessionProvider = context.watch<SessionProvider>();
    final patientProvider = context.watch<PatientProvider>();
    final patientsMap = {for (var p in patientProvider.patients) p.id: p.name};

    // Filter sessions locally in real-time based on selected month and year
    final monthlySessions = sessionProvider.sessions.where((session) {
      return session.date.year == _selectedYear && session.date.month == _selectedMonth;
    }).toList();

    // Calculations
    final totalSessions = monthlySessions.length;
    final completedCount = monthlySessions.where((s) => s.status == SessionStatus.completed).length;
    final postponedCount = monthlySessions.where((s) => s.status == SessionStatus.postponed).length;
    final cancelledCount = monthlySessions.where((s) => s.status == SessionStatus.cancelled).length;

    // Monthly income = sum of paidAmount from completed sessions only
    final totalIncome = monthlySessions
        .where((s) => s.status == SessionStatus.completed)
        .fold(0.0, (sum, s) => sum + s.paidAmount);

    // Outstanding remaining amount from completed sessions
    final outstandingAmount = monthlySessions
        .where((s) => s.status == SessionStatus.completed)
        .fold(0.0, (sum, s) => sum + s.remainingAmount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('التقارير المالية والتحليلات'),
      ),
      body: Column(
        children: [
          // ── Month & Year Selectors ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            color: theme.colorScheme.surface,
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedMonth,
                    decoration: const InputDecoration(
                      labelText: 'الشهر',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: List.generate(12, (index) {
                      final monthNum = index + 1;
                      return DropdownMenuItem<int>(
                        value: monthNum,
                        child: Text(DateHelper.getArabicMonthName(monthNum)),
                      );
                    }),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedMonth = value;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedYear,
                    decoration: const InputDecoration(
                      labelText: 'السنة',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: _yearsList.map((year) {
                      return DropdownMenuItem<int>(
                        value: year,
                        child: Text(year.toString()),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedYear = value;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Summary Cards ──────────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // Financial Grid Row
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        context,
                        'الدخل المستلم',
                        '${totalIncome.toStringAsFixed(0)} ج.م',
                        Icons.account_balance_wallet,
                        isDark ? Colors.green.shade300 : Colors.green.shade700,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildMetricCard(
                        context,
                        'المبالغ المتبقية',
                        '${outstandingAmount.toStringAsFixed(0)} ج.م',
                        Icons.pending_actions,
                        isDark ? Colors.orange.shade300 : Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Sessions Count Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'إحصائيات الجلسات للشهر',
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                              child: Icon(
                                Icons.analytics,
                                color: theme.colorScheme.primary,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatColumn(context, 'الإجمالي', totalSessions.toString(), theme.colorScheme.primary),
                            _buildStatColumn(context, 'مكتملة', completedCount.toString(), Colors.green),
                            _buildStatColumn(context, 'مؤجلة', postponedCount.toString(), Colors.orange),
                            _buildStatColumn(context, 'ملغاة', cancelledCount.toString(), Colors.red),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Monthly Sessions list header
                Text(
                  'تفاصيل الجلسات لشهر ${DateHelper.getArabicMonthName(_selectedMonth)} ($_selectedYear)',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                if (monthlySessions.isEmpty)
                  Container(
                    height: 150,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_note,
                          color: theme.colorScheme.onSurface.withOpacity(0.4),
                          size: 48,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'لا توجد جلسات مسجلة في هذا الشهر',
                          style: textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: monthlySessions.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final session = monthlySessions[index];
                      final patientName = patientsMap[session.patientId] ?? 'مريض غير معروف';
                      return SessionCard(
                        session: session,
                        patientName: patientName,
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 4),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        Text(
          value,
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ],
    );
  }
}
