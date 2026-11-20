import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:physical_therapy/app/routes.dart';
import 'package:physical_therapy/core/constants/app_colors.dart';
import 'package:physical_therapy/core/utils/date_helper.dart';
import 'package:physical_therapy/features/sessions/add_session_view.dart';
import 'package:physical_therapy/models/session_model.dart';
import 'package:physical_therapy/providers/patient_provider.dart';
import 'package:physical_therapy/providers/session_provider.dart';
import 'package:provider/provider.dart';

enum ScheduleViewMode { daily, weekly }

class ScheduleView extends StatefulWidget {
  const ScheduleView({super.key});

  @override
  State<ScheduleView> createState() => _ScheduleViewState();
}

class _ScheduleViewState extends State<ScheduleView> {
  ScheduleViewMode _mode = ScheduleViewMode.daily;
  DateTime _selectedDate = DateTime.now();

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

  void _goToToday() {
    setState(() {
      _selectedDate = DateTime.now();
    });
  }

  void _prevPeriod() {
    setState(() {
      if (_mode == ScheduleViewMode.daily) {
        _selectedDate = _selectedDate.subtract(const Duration(days: 1));
      } else {
        _selectedDate = _selectedDate.subtract(const Duration(days: 7));
      }
    });
  }

  void _nextPeriod() {
    setState(() {
      if (_mode == ScheduleViewMode.daily) {
        _selectedDate = _selectedDate.add(const Duration(days: 1));
      } else {
        _selectedDate = _selectedDate.add(const Duration(days: 7));
      }
    });
  }

  /// Finds Saturday as the start of the week.
  DateTime _getStartOfWeek(DateTime date) {
    // DateTime.weekday: Monday=1 ... Saturday=6, Sunday=7
    final weekday = date.weekday;
    final daysToSubtract = (weekday % 7 + 1) % 7;
    final sat = date.subtract(Duration(days: daysToSubtract));
    return DateTime(sat.year, sat.month, sat.day);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    final sessionProvider = context.watch<SessionProvider>();
    final patientProvider = context.watch<PatientProvider>();
    final patientsMap = {for (var p in patientProvider.patients) p.id: p.name};

    // Filter out cancelled sessions for the grid/schedule view
    final visibleSessions = sessionProvider.sessions
        .where((s) => s.status != SessionStatus.cancelled)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('الجدول'),
        actions: [
          TextButton.icon(
            onPressed: _goToToday,
            icon: const Icon(Icons.today, size: 18),
            label: const Text('اليوم'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(
            context,
            AppRoutes.addSession,
            arguments: AddSessionArgs(
              initialDateTime: _selectedDate,
            ),
          );
        },
        tooltip: 'إضافة جلسة',
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // ── Toggle and Date Navigation Bar ─────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            color: theme.colorScheme.surface,
            child: Column(
              children: [
                // Segmented Toggle
                SegmentedButton<ScheduleViewMode>(
                  segments: const [
                    ButtonSegment(
                      value: ScheduleViewMode.daily,
                      label: Text('يومي'),
                      icon: Icon(Icons.view_day_outlined),
                    ),
                    ButtonSegment(
                      value: ScheduleViewMode.weekly,
                      label: Text('أسبوعي'),
                      icon: Icon(Icons.view_week_outlined),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (newSelection) {
                    setState(() {
                      _mode = newSelection.first;
                    });
                  },
                ),
                const SizedBox(height: 8),

                // Date Navigation
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_right), // In RTL, right is previous
                      onPressed: _prevPeriod,
                      tooltip: 'السابق',
                    ),
                    Text(
                      _mode == ScheduleViewMode.daily
                          ? DateFormat('EEEE، yyyy/MM/dd', 'ar').format(_selectedDate)
                          : _formatWeekRange(_selectedDate),
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_left), // In RTL, left is next
                      onPressed: _nextPeriod,
                      tooltip: 'التالي',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── Content ────────────────────────────────────────────────────────
          Expanded(
            child: _mode == ScheduleViewMode.daily
                ? _buildDailyTimeline(context, visibleSessions, patientsMap)
                : _buildWeeklyView(context, visibleSessions, patientsMap),
          ),
        ],
      ),
    );
  }

  String _formatWeekRange(DateTime date) {
    final start = _getStartOfWeek(date);
    final end = start.add(const Duration(days: 6));
    final f = DateFormat('yyyy/MM/dd');
    return '${f.format(start)} - ${f.format(end)}';
  }

  // ── Daily View (Timeline) ──────────────────────────────────────────────────
  Widget _buildDailyTimeline(
    BuildContext context,
    List<SessionModel> sessions,
    Map<String, String> patientsMap,
  ) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    // Filter sessions for the selected day
    final daySessions = sessions.where((s) {
      return s.date.year == _selectedDate.year &&
          s.date.month == _selectedDate.month &&
          s.date.day == _selectedDate.day;
    }).toList();

    // Determine hour range (default 07:00 to 23:00, extended if any session falls outside)
    int minHour = 7;
    int maxHour = 23;
    for (final s in daySessions) {
      if (s.date.hour < minHour) minHour = s.date.hour;
      final endHour = s.date.add(Duration(minutes: s.durationMinutes)).hour + 1;
      if (endHour > maxHour) maxHour = endHour.clamp(0, 24);
    }

    const double hourHeight = 64.0;
    final totalHours = maxHour - minHour;
    final totalHeight = totalHours * hourHeight;

    // Detect overlapping clusters to layout side-by-side
    final clusters = _computeOverlappingClusters(daySessions);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 80.0),
      child: SizedBox(
        height: totalHeight,
        child: Stack(
          children: [
            // Hour horizontal grid lines & labels
            for (int i = 0; i <= totalHours; i++) ...[
              Positioned(
                top: i * hourHeight,
                left: 0,
                right: 0,
                child: Row(
                  children: [
                    SizedBox(
                      width: 60,
                      child: Text(
                        '${(minHour + i).toString().padLeft(2, '0')}:00',
                        textAlign: TextAlign.center,
                        style: textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        height: 1,
                        color: theme.dividerColor.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Session Blocks
            for (final cluster in clusters)
              for (int colIndex = 0; colIndex < cluster.length; colIndex++) ...[
                _buildSessionBlock(
                  context: context,
                  session: cluster[colIndex],
                  patientName: patientsMap[cluster[colIndex].patientId] ?? 'مريض غير معروف',
                  minHour: minHour,
                  hourHeight: hourHeight,
                  colIndex: colIndex,
                  totalCols: cluster.length,
                ),
              ],
          ],
        ),
      ),
    );
  }

  /// Groups overlapping sessions so they can be drawn side-by-side with equal width.
  List<List<SessionModel>> _computeOverlappingClusters(List<SessionModel> sessions) {
    if (sessions.isEmpty) return [];

    final sorted = List<SessionModel>.from(sessions)
      ..sort((a, b) => a.date.compareTo(b.date));

    final List<List<SessionModel>> clusters = [];
    List<SessionModel> currentCluster = [sorted.first];
    DateTime currentClusterEnd = sorted.first.date.add(Duration(minutes: sorted.first.durationMinutes));

    for (int i = 1; i < sorted.length; i++) {
      final s = sorted[i];
      if (s.date.isBefore(currentClusterEnd)) {
        // Overlaps with current cluster
        currentCluster.add(s);
        final sEnd = s.date.add(Duration(minutes: s.durationMinutes));
        if (sEnd.isAfter(currentClusterEnd)) {
          currentClusterEnd = sEnd;
        }
      } else {
        clusters.add(currentCluster);
        currentCluster = [s];
        currentClusterEnd = s.date.add(Duration(minutes: s.durationMinutes));
      }
    }
    clusters.add(currentCluster);

    return clusters;
  }

  Widget _buildSessionBlock({
    required BuildContext context,
    required SessionModel session,
    required String patientName,
    required int minHour,
    required double hourHeight,
    required int colIndex,
    required int totalCols,
  }) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    final startMinutes = (session.date.hour - minHour) * 60 + session.date.minute;
    final top = (startMinutes / 60.0) * hourHeight;
    final height = (session.durationMinutes / 60.0) * hourHeight;
    final statusColor = _getStatusColor(session.status, theme);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Timeline margin on left is 60px for hour labels
        final availableWidth = constraints.maxWidth - 68;
        final colWidth = availableWidth / totalCols;
        final leftOffset = 64 + (colIndex * colWidth);

        return Positioned(
          top: top,
          left: leftOffset,
          width: colWidth - 4,
          height: height.clamp(28.0, 400.0),
          child: InkWell(
            onTap: () {
              Navigator.pushNamed(
                context,
                AppRoutes.editSession,
                arguments: session,
              );
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: statusColor.withValues(alpha: 0.8), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    patientName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    DateHelper.formatTime(session.date),
                    maxLines: 1,
                    style: textTheme.labelSmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Weekly View ────────────────────────────────────────────────────────────
  Widget _buildWeeklyView(
    BuildContext context,
    List<SessionModel> sessions,
    Map<String, String> patientsMap,
  ) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final startOfWeek = _getStartOfWeek(_selectedDate);

    return ListView.separated(
      padding: const EdgeInsets.all(16.0),
      itemCount: 7,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final day = startOfWeek.add(Duration(days: index));
        final daySessions = sessions.where((s) {
          return s.date.year == day.year &&
              s.date.month == day.month &&
              s.date.day == day.day;
        }).toList()
          ..sort((a, b) => a.date.compareTo(b.date));

        final isToday = day.year == DateTime.now().year &&
            day.month == DateTime.now().month &&
            day.day == DateTime.now().day;

        return Card(
          elevation: isToday ? 2 : 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isToday
                  ? theme.colorScheme.primary
                  : theme.dividerColor.withValues(alpha: 0.4),
              width: isToday ? 1.5 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Day header
                InkWell(
                  onTap: () {
                    setState(() {
                      _selectedDate = day;
                      _mode = ScheduleViewMode.daily;
                    });
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            DateFormat('EEEE', 'ar').format(day),
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isToday ? theme.colorScheme.primary : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('yyyy/MM/dd').format(day),
                            style: textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Sessions chips
                if (daySessions.isEmpty)
                  Text(
                    'لا توجد جلسات مجدولة',
                    style: textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: daySessions.map((session) {
                      final pName = patientsMap[session.patientId] ?? 'مريض';
                      final statusColor = _getStatusColor(session.status, theme);
                      final timeStr = DateHelper.formatTime(session.date);

                      return InkWell(
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            AppRoutes.editSession,
                            arguments: session,
                          );
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 4,
                                backgroundColor: statusColor,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '$timeStr • $pName',
                                style: textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
