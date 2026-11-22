import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:physical_therapy/features/sessions/widgets/session_card.dart';
import 'package:physical_therapy/models/session_model.dart';
import 'package:physical_therapy/providers/patient_provider.dart';
import 'package:physical_therapy/providers/session_provider.dart';
import 'package:physical_therapy/widgets/loading_widget.dart';
import 'package:provider/provider.dart';

class SessionsView extends StatefulWidget {
  const SessionsView({super.key});

  @override
  State<SessionsView> createState() => _SessionsViewState();
}

class _SessionsViewState extends State<SessionsView> {
  SessionStatus? _statusFilter;
  DateTimeRange? _dateRange;

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _dateRange,
    );
    if (picked != null) {
      setState(() {
        _dateRange = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    final patientProvider = context.watch<PatientProvider>();
    final patientsMap = {for (var p in patientProvider.patients) p.id: p.name};

    return Scaffold(
      appBar: AppBar(
        title: const Text('جميع الجلسات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            tooltip: 'تصفية بالتاريخ',
            onPressed: _selectDateRange,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Filter Chips ───────────────────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('الكل'),
                  selected: _statusFilter == null,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _statusFilter = null;
                      });
                    }
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('محجوزة'),
                  selected: _statusFilter == SessionStatus.scheduled,
                  selectedColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                  checkmarkColor: theme.colorScheme.primary,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _statusFilter = SessionStatus.scheduled;
                      });
                    }
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('مكتملة'),
                  selected: _statusFilter == SessionStatus.completed,
                  selectedColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                  checkmarkColor: theme.colorScheme.primary,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _statusFilter = SessionStatus.completed;
                      });
                    }
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('مؤجلة'),
                  selected: _statusFilter == SessionStatus.postponed,
                  selectedColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                  checkmarkColor: theme.colorScheme.primary,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _statusFilter = SessionStatus.postponed;
                      });
                    }
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('ملغاة'),
                  selected: _statusFilter == SessionStatus.cancelled,
                  selectedColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                  checkmarkColor: theme.colorScheme.primary,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _statusFilter = SessionStatus.cancelled;
                      });
                    }
                  },
                ),
              ],
            ),
          ),

          // ── Date Range Removable Chip (if set) ─────────────────────────────
          if (_dateRange != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Row(
                children: [
                  InputChip(
                    avatar: const Icon(Icons.date_range, size: 16),
                    label: Text(
                      'من ${DateFormat('yyyy/MM/dd').format(_dateRange!.start)} إلى ${DateFormat('yyyy/MM/dd').format(_dateRange!.end)}',
                    ),
                    onDeleted: () {
                      setState(() {
                        _dateRange = null;
                      });
                    },
                    deleteIcon: const Icon(Icons.close, size: 16),
                  ),
                ],
              ),
            ),

          // ── Sessions List ──────────────────────────────────────────────────
          Expanded(
            child: Consumer<SessionProvider>(
              builder: (context, sessionProvider, child) {
                if (sessionProvider.isLoading && sessionProvider.sessions.isEmpty) {
                  return const LoadingWidget(message: 'جاري تحميل الجلسات...');
                }

                if (sessionProvider.error != null && sessionProvider.sessions.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        'حدث خطأ أثناء تحميل الجلسات: ${sessionProvider.error}',
                        style: textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  );
                }

                final filteredSessions = sessionProvider.sessions.where((session) {
                  // Status filter
                  if (_statusFilter != null && session.status != _statusFilter) {
                    return false;
                  }
                  // Date range filter: whole days inclusive
                  if (_dateRange != null) {
                    final startOfDay = DateTime(
                      _dateRange!.start.year,
                      _dateRange!.start.month,
                      _dateRange!.start.day,
                    );
                    final endOfDay = DateTime(
                      _dateRange!.end.year,
                      _dateRange!.end.month,
                      _dateRange!.end.day,
                      23,
                      59,
                      59,
                    );
                    if (session.date.isBefore(startOfDay) || session.date.isAfter(endOfDay)) {
                      return false;
                    }
                  }
                  return true;
                }).toList();

                if (filteredSessions.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_busy,
                          size: 64,
                          color: theme.colorScheme.primary.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'لا يوجد جلسات مطابقة للفحص الحالي',
                          style: textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: filteredSessions.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final session = filteredSessions[index];
                    final patientName = patientsMap[session.patientId] ?? 'مريض غير معروف';
                    return SessionCard(
                      session: session,
                      patientName: patientName,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
