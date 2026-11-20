import 'package:flutter/material.dart';
import 'package:physical_therapy/app/routes.dart';
import 'package:physical_therapy/features/dashboard/widgets/income_card.dart';
import 'package:physical_therapy/features/dashboard/widgets/today_session_card.dart';
import 'package:physical_therapy/providers/patient_provider.dart';
import 'package:physical_therapy/providers/session_provider.dart';
import 'package:physical_therapy/widgets/loading_widget.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  Future<void> _makeCall(BuildContext context, String phone) async {
    final Uri uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر إجراء المكالمة')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    final patientProvider = context.watch<PatientProvider>();
    final sessionProvider = context.watch<SessionProvider>();

    final patientsMap = {for (var p in patientProvider.patients) p.id: p};
    final todaySessions = sessionProvider.todaySessions;
    final income = sessionProvider.monthlyIncome;

    return Scaffold(
      appBar: AppBar(
        title: const Text('عيادة العلاج الطبيعي'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.settings);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Both streams update in real-time, but manual refresh re-fetches patient details
          // which helps sync if there is any lag.
        },
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // ── Welcome Banner ───────────────────────────────────────────────
            Text(
              'مرحباً بك 👋',
              style: textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'نظرة عامة على العيادة اليوم',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // ── Income Card ──────────────────────────────────────────────────
            IncomeCard(amount: income),
            const SizedBox(height: 24),

            // ── Quick Navigation Grid ────────────────────────────────────────
            Text(
              'إدارة العيادة',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.1,
              children: [
                _buildGridItem(
                  context,
                  'المرضى',
                  Icons.people,
                  theme.colorScheme.primary,
                  AppRoutes.patients,
                ),
                _buildGridItem(
                  context,
                  'الجلسات',
                  Icons.event_note,
                  theme.colorScheme.secondary,
                  AppRoutes.sessions,
                ),
                _buildGridItem(
                  context,
                  'التقارير',
                  Icons.analytics,
                  Colors.purple,
                  AppRoutes.reports,
                ),
              ],
            ),
            const SizedBox(height: 28),

            // ── Today's Sessions Queue ───────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'جلسات اليوم (${todaySessions.length})',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.addSession,
                    );
                  },
                  child: const Text('حجز جلسة جديدة'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (sessionProvider.isLoading && todaySessions.isEmpty)
              const SizedBox(
                height: 150,
                child: LoadingWidget(message: 'جاري تحميل جلسات اليوم...'),
              )
            else if (todaySessions.isEmpty)
              Container(
                height: 120,
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
                      Icons.event_available,
                      color: theme.colorScheme.secondary.withOpacity(0.5),
                      size: 40,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'لا يوجد جلسات مجدولة لليوم',
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
                itemCount: todaySessions.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final session = todaySessions[index];
                  final patient = patientsMap[session.patientId];
                  final patientName = patient?.name ?? 'مريض غير معروف';
                  final patientPhone = patient?.phone ?? '';

                  return TodaySessionCard(
                    session: session,
                    patientName: patientName,
                    onCallPressed: () {
                      if (patientPhone.isNotEmpty) {
                        _makeCall(context, patientPhone);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('رقم الهاتف غير مسجل للمريض')),
                        );
                      }
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridItem(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    String route,
  ) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withOpacity(0.5)),
      ),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(context, route);
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: color.withOpacity(0.12),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
