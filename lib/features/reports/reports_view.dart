import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:physical_therapy/core/utils/date_helper.dart';
import 'package:physical_therapy/core/utils/debt_calculator.dart';
import 'package:physical_therapy/features/sessions/widgets/session_card.dart';
import 'package:physical_therapy/models/session_model.dart';
import 'package:physical_therapy/providers/debt_provider.dart';
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
    final debtProvider = context.watch<DebtProvider>();
    final patientsMap = {for (var p in patientProvider.patients) p.id: p.name};

    // Filter sessions locally in real-time based on selected month and year
    final monthlySessions = sessionProvider.sessions.where((session) {
      return session.date.year == _selectedYear && session.date.month == _selectedMonth;
    }).toList();

    // Calculations
    final totalSessions = monthlySessions.length;
    final scheduledCount = monthlySessions.where((s) => s.status == SessionStatus.scheduled).length;
    final completedCount = monthlySessions.where((s) => s.status == SessionStatus.completed).length;
    final postponedCount = monthlySessions.where((s) => s.status == SessionStatus.postponed).length;
    final cancelledCount = monthlySessions.where((s) => s.status == SessionStatus.cancelled).length;

    // Debt repayments in this month
    final monthlyDebtPayments = debtProvider.debtPayments.where((p) {
      return p.paidAt.year == _selectedYear && p.paidAt.month == _selectedMonth;
    }).fold<double>(0.0, (sum, p) => sum + p.amount);

    // Monthly income = cash basis (completed sessions + debt repayments in that month)
    final totalIncome = incomeForMonth(
      sessions: sessionProvider.sessions,
      debtPayments: debtProvider.debtPayments,
      year: _selectedYear,
      month: _selectedMonth,
    );

    // Current total outstanding across ALL patients (not month-filtered)
    final totalCurrentOutstanding = DebtCalculator.calculateTotalOutstandingDebt(
      patientIds: patientProvider.patients.map((p) => p.id).toList(),
      sessions: sessionProvider.sessions,
      debtPayments: debtProvider.debtPayments,
    );

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
                    initialValue: _selectedMonth,
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
                    initialValue: _selectedYear,
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
                        subText: 'منها سداد مديونيات: ${monthlyDebtPayments.toStringAsFixed(0)} ج.م',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildMetricCard(
                        context,
                        'إجمالي المديونيات الحالية',
                        '${totalCurrentOutstanding.toStringAsFixed(0)} ج.م',
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
                              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
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
                            _buildStatColumn(context, 'محجوزة', scheduledCount.toString(), theme.colorScheme.primary),
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

                // ── Monthly Income Trend (Bar Chart) ─────────────────────────
                _buildIncomeBarChart(context, sessionProvider.sessions, debtProvider.debtPayments),
                const SizedBox(height: 16),

                // ── Daily Completed Sessions Trend (Line Chart) ──────────────
                _buildDailyCompletedLineChart(context, monthlySessions),
                const SizedBox(height: 24),

                // ── Paid commissions history ──────────────────────────────────
                Text(
                  'سجل العمولات المدفوعة',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: patientProvider.getPaidCommissionsStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Text('حدث خطأ في تحميل سجل العمولات: ${snapshot.error}');
                    }
                    final history = snapshot.data ?? [];
                    if (history.isEmpty) {
                      return Container(
                        height: 100,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          'لا يوجد سجل عمولات مدفوعة بعد',
                          style: textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      );
                    }

                    // Group entries by patientId for a cleaner per-patient view
                    final grouped = <String, List<Map<String, dynamic>>>{};
                    for (final log in history) {
                      final pid = log['patientId'] as String;
                      grouped.putIfAbsent(pid, () => []).add(log);
                    }
                    final groupKeys = grouped.keys.toList();

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: groupKeys.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final patientId = groupKeys[index];
                        final entries = grouped[patientId]!;
                        // Primary: name stored at write-time in Firestore (never stale).
                        // Fallback: in-memory patients map (covers legacy docs without name).
                        final storedName = entries.first['patientName'] as String? ?? '';
                        final patientName = storedName.isNotEmpty
                            ? storedName
                            : (patientsMap[patientId] ?? 'مريض غير معروف');
                        final totalPaid = entries.fold<double>(
                          0.0,
                          (sum, e) => sum + (e['amount'] as double),
                        );

                        return Card(
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Patient header row
                              ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.green.withValues(alpha: 0.12),
                                  child: const Icon(Icons.person, color: Colors.green),
                                ),
                                title: Text(
                                  patientName,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text('عدد الدفعات: ${entries.length}'),
                                trailing: Text(
                                  '${totalPaid.toStringAsFixed(0)} ج.م',
                                  style: textTheme.titleMedium?.copyWith(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              // Individual payment sub-rows
                              const Divider(height: 1),
                              ...entries.map((log) {
                                final entryAmount = log['amount'] as double;
                                final paidAt = log['paidAt'] as DateTime;
                                final formattedDate =
                                    '${paidAt.year}/${paidAt.month.toString().padLeft(2, '0')}/${paidAt.day.toString().padLeft(2, '0')}';
                                return ListTile(
                                  dense: true,
                                  leading: const Icon(
                                    Icons.check_circle_outline,
                                    color: Colors.green,
                                    size: 18,
                                  ),
                                  title: Text(
                                    'تاريخ الدفع: $formattedDate',
                                    style: textTheme.bodySmall,
                                  ),
                                  trailing: Text(
                                    '${entryAmount.toStringAsFixed(0)} ج.م',
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: Colors.green,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 32),

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
                      border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_note,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                          size: 48,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'لا توجد جلسات مسجلة في هذا الشهر',
                          style: textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
                const SizedBox(height: 32),
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
    Color color, {
    String? subText,
  }) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
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
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
            if (subText != null) ...[
              const SizedBox(height: 4),
              Text(
                subText,
                style: textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ],
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
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  // ── Monthly Income Trend (Bar Chart) ───────────────────────────────────────
  Widget _buildIncomeBarChart(
    BuildContext context,
    List<SessionModel> allSessions,
    List<dynamic> allDebtPayments,
  ) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    // Last 6 months up to selected year/month
    final List<({int year, int month, double income})> monthsData = [];
    for (int i = 5; i >= 0; i--) {
      int y = _selectedYear;
      int m = _selectedMonth - i;
      while (m <= 0) {
        m += 12;
        y -= 1;
      }
      final inc = incomeForMonth(
        sessions: allSessions,
        debtPayments: allDebtPayments.cast(),
        year: y,
        month: m,
      );
      monthsData.add((year: y, month: m, income: inc));
    }

    double maxVal = 0;
    for (final md in monthsData) {
      if (md.income > maxVal) maxVal = md.income;
    }
    final maxY = maxVal > 0 ? (maxVal * 1.25) : 100.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'اتجاه الدخل الشهري (آخر 6 أشهر)',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final md = monthsData[group.x.toInt()];
                        final monthName = DateHelper.getArabicMonthName(md.month);
                        return BarTooltipItem(
                          '$monthName\n${rod.toY.toStringAsFixed(0)} ج.م',
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= monthsData.length) {
                            return const SizedBox.shrink();
                          }
                          final m = monthsData[idx].month;
                          final mName = DateHelper.getArabicMonthName(m);
                          final shortName = mName.length > 4 ? mName.substring(0, 4) : mName;
                          return Padding(
                            padding: const EdgeInsets.only(top: 6.0),
                            child: Text(
                              shortName,
                              style: textTheme.bodySmall?.copyWith(fontSize: 10),
                            ),
                          );
                        },
                        reservedSize: 28,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 42,
                        getTitlesWidget: (value, meta) {
                          if (value == 0) return const SizedBox.shrink();
                          return Text(
                            value.toInt().toString(),
                            style: textTheme.bodySmall?.copyWith(fontSize: 9),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxY / 4,
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(monthsData.length, (idx) {
                    final d = monthsData[idx];
                    return BarChartGroupData(
                      x: idx,
                      barRods: [
                        BarChartRodData(
                          toY: d.income,
                          color: theme.colorScheme.primary,
                          width: 18,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Daily Completed Sessions Trend (Line Chart) ────────────────────────────
  Widget _buildDailyCompletedLineChart(
    BuildContext context,
    List<SessionModel> monthlySessions,
  ) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    final daysInMonth = DateUtils.getDaysInMonth(_selectedYear, _selectedMonth);
    final Map<int, int> completedPerDay = {};
    for (int day = 1; day <= daysInMonth; day++) {
      completedPerDay[day] = 0;
    }

    for (final s in monthlySessions) {
      if (s.status == SessionStatus.completed) {
        completedPerDay[s.date.day] = (completedPerDay[s.date.day] ?? 0) + 1;
      }
    }

    final spots = <FlSpot>[];
    int maxCompleted = 0;
    for (int day = 1; day <= daysInMonth; day++) {
      final count = completedPerDay[day] ?? 0;
      if (count > maxCompleted) maxCompleted = count;
      spots.add(FlSpot(day.toDouble(), count.toDouble()));
    }

    final maxY = maxCompleted > 0 ? (maxCompleted + 1).toDouble() : 5.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'الجلسات المكتملة يومياً لشهر ${DateHelper.getArabicMonthName(_selectedMonth)}',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  minX: 1,
                  maxX: daysInMonth.toDouble(),
                  minY: 0,
                  maxY: maxY,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 1,
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 5,
                        getTitlesWidget: (value, meta) {
                          if (value == 0 || value > daysInMonth) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              '${value.toInt()}',
                              style: textTheme.bodySmall?.copyWith(fontSize: 10),
                            ),
                          );
                        },
                        reservedSize: 24,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: textTheme.bodySmall?.copyWith(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: theme.colorScheme.secondary,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: theme.colorScheme.secondary.withValues(alpha: 0.15),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
