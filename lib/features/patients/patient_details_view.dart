import 'package:flutter/material.dart';
import 'package:physical_therapy/app/routes.dart';
import 'package:physical_therapy/core/constants/app_colors.dart';
import 'package:physical_therapy/core/services/maps_service.dart';
import 'package:physical_therapy/core/services/reminder_service.dart';
import 'package:physical_therapy/core/utils/debt_calculator.dart';
import 'package:physical_therapy/core/utils/phone_utils.dart';
import 'package:physical_therapy/core/utils/plan_calculator.dart';
import 'package:physical_therapy/features/sessions/widgets/session_card.dart';
import 'package:physical_therapy/models/patient_model.dart';
import 'package:physical_therapy/providers/debt_provider.dart';
import 'package:physical_therapy/providers/patient_provider.dart';
import 'package:physical_therapy/providers/session_provider.dart';
import 'package:physical_therapy/widgets/gradient_card.dart';
import 'package:physical_therapy/widgets/loading_widget.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class PatientDetailsView extends StatefulWidget {
  final PatientModel patient;

  const PatientDetailsView({super.key, required this.patient});

  @override
  State<PatientDetailsView> createState() => _PatientDetailsViewState();
}

class _PatientDetailsViewState extends State<PatientDetailsView> {
  late PatientModel _currentPatient;

  @override
  void initState() {
    super.initState();
    _currentPatient = widget.patient;
  }

  Future<void> _openWhatsApp() async {
    if (_currentPatient.phone.isEmpty) return;
    final message = 'مرحباً ${_currentPatient.name}، موعدك القادم في العيادة';
    final success = await PhoneUtils.launchWhatsApp(
      phone: _currentPatient.phone,
      message: message,
    );
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح واتساب')),
      );
    }
  }

  Future<void> _makeCall(String phone) async {
    final Uri uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر إجراء المكالمة')),
        );
      }
    }
  }

  Future<void> _openLocation() async {
    if (_currentPatient.location == null) return;
    final lat = _currentPatient.location!.latitude;
    final lng = _currentPatient.location!.longitude;

    final success = await MapsService.openGoogleMaps(lat, lng);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح خرائط Google')),
      );
    }
  }

  Future<void> _toggleTreatmentEnded() async {
    final willEnd = !_currentPatient.treatmentEnded;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(willEnd ? 'إنهاء العلاج' : 'إعادة تفعيل العلاج'),
        content: Text(
          willEnd
              ? 'سيتم الاحتفاظ ببيانات المريض وكل جلساته'
              : 'سيتم إعادة تفعيل ملف المريض لإضافة جلسات جديدة',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(willEnd ? 'إنهاء العلاج' : 'إعادة تفعيل'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final provider = context.read<PatientProvider>();
      await provider.setTreatmentEnded(_currentPatient, willEnd);
      if (mounted) {
        if (provider.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('حدث خطأ: ${provider.error}'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                willEnd ? 'تم إنهاء علاج المريض بنجاح' : 'تم إعادة تفعيل العلاج بنجاح',
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _deletePatient() async {
    final step1 = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تحذير: حذف نهائي'),
        content: const Text(
          'سيتم حذف المريض وكل جلساته ومدفوعاته نهائياً وسيتغير دخل الشهور السابقة',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('متابعة'),
          ),
        ],
      ),
    );

    if (step1 != true || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف النهائي'),
        content: Text(
          'هل أنت متأكد تماماً من حذف "${_currentPatient.name}" نهائياً؟ لا يمكن التراجع عن هذا الإجراء.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('حذف نهائي'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final sessionProvider = context.read<SessionProvider>();
      final patientSessions = sessionProvider.patientSessions(_currentPatient.id);
      for (final s in patientSessions) {
        await ReminderService().cancelSessionReminder(s.id);
      }
      final provider = context.read<PatientProvider>();
      await provider.deletePatient(_currentPatient.id);

      if (mounted) {
        if (provider.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('حدث خطأ أثناء الحذف: ${provider.error}'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حذف المريض وجميع بياناته بنجاح')),
          );
          Navigator.pop(context);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;

    final patientProvider = context.watch<PatientProvider>();
    final sessionProvider = context.watch<SessionProvider>();
    final debtProvider = context.watch<DebtProvider>();

    final updatedPatient = patientProvider.patients.firstWhere(
      (p) => p.id == _currentPatient.id,
      orElse: () => _currentPatient,
    );
    _currentPatient = updatedPatient;

    final sessions = sessionProvider.patientSessions(_currentPatient.id);
    final allSessions = sessionProvider.sessions;
    final debtPayments = debtProvider.debtPayments;

    // Debt calculation (Workstream C3)
    final outstandingDebt = DebtCalculator.calculateOutstandingDebt(
      patientId: _currentPatient.id,
      sessions: allSessions,
      debtPayments: debtPayments,
    );

    // Plan calculation (Workstream C4)
    final hasPlan = _currentPatient.planTotalSessions != null &&
        _currentPatient.planStartDate != null;
    final planUsed = PlanCalculator.calculateUsedSessions(
      patient: _currentPatient,
      sessions: allSessions,
    );
    final planRemaining = PlanCalculator.calculateRemainingSessions(
      patient: _currentPatient,
      sessions: allSessions,
    );
    final planState = PlanCalculator.getPlanState(
      patient: _currentPatient,
      sessions: allSessions,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentPatient.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'تعديل بيانات المريض',
            onPressed: () async {
              await Navigator.pushNamed(
                context,
                AppRoutes.editPatient,
                arguments: _currentPatient,
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Patient Info Card ──────────────────────────────────────────────
          GradientCard(
            margin: const EdgeInsets.all(16.0),
            padding: const EdgeInsets.all(16.0),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                        child: Icon(
                          Icons.person,
                          size: 32,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentPatient.name,
                              style: textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _currentPatient.phone,
                              style: textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 20,
                        color: theme.colorScheme.secondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _currentPatient.address.isNotEmpty
                              ? _currentPatient.address
                              : 'لا يوجد عنوان مسجل',
                          style: textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  if (_currentPatient.medicalNotes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.medical_services,
                          size: 20,
                          color: theme.colorScheme.secondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _currentPatient.medicalNotes,
                            style: textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _currentPatient.phone.isNotEmpty
                              ? () => _makeCall(_currentPatient.phone)
                              : null,
                          icon: const Icon(Icons.phone),
                          label: const Text('اتصال مباشر'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      if (_currentPatient.phone.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _openWhatsApp,
                            icon: const Icon(Icons.chat),
                            label: const Text('واتساب'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                      if (_currentPatient.location != null) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _openLocation,
                            icon: const Icon(Icons.map),
                            label: const Text('الموقع'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
          ),

          // ── Outstanding Debt Row/Card (Workstream C3) ──────────────────────
          if (outstandingDebt > 0)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              decoration: BoxDecoration(
                color: (isDark ? AppColors.darkError : AppColors.lightError)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (isDark ? AppColors.darkError : AppColors.lightError)
                      .withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet_outlined,
                        color: isDark ? AppColors.darkError : AppColors.lightError,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'إجمالي المديونية المستحقة:',
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${outstandingDebt.toStringAsFixed(0)} ج.م',
                    style: textTheme.titleMedium?.copyWith(
                      color: isDark ? AppColors.darkError : AppColors.lightError,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

          // ── Treatment Plan / Package Card (Workstream C4) ──────────────────
          if (hasPlan)
            GradientCard(
              margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
                              Icons.inventory_2_outlined,
                              color: theme.colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'باقة العلاج',
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        if (planState == PlanState.low)
                          Text(
                            'قاربت الباقة على الانتهاء',
                            style: textTheme.labelSmall?.copyWith(
                              color: isDark ? AppColors.darkWarning : AppColors.lightWarning,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        else if (planState == PlanState.finished)
                          Text(
                            'انتهت الباقة',
                            style: textTheme.labelSmall?.copyWith(
                              color: isDark ? AppColors.darkError : AppColors.lightError,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: _currentPatient.planTotalSessions! > 0
                          ? (planUsed / _currentPatient.planTotalSessions!).clamp(0.0, 1.0)
                          : 1.0,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                      color: planState == PlanState.finished
                          ? (isDark ? AppColors.darkError : AppColors.lightError)
                          : (planState == PlanState.low
                              ? (isDark ? AppColors.darkWarning : AppColors.lightWarning)
                              : theme.colorScheme.primary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'المتبقي $planRemaining من ${_currentPatient.planTotalSessions} جلسات ($planUsed مكتملة)',
                      style: textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
            ),

          // ── Commission Tracking Card ──────────────────────────────────────
          if (_currentPatient.commissionEnabled) ...[
            GradientCard(
              margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              padding: const EdgeInsets.all(16.0),
              child: Row(
                  children: [
                    Icon(
                      Icons.monetization_on,
                      color: _currentPatient.commissionCycleState == 'due'
                          ? (isDark ? AppColors.darkError : AppColors.lightError)
                          : (isDark ? AppColors.darkWarning : AppColors.lightWarning),
                      size: 24,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'تتبع العمولة',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (_currentPatient.commissionCycleState == 'inProgress')
                            Text(
                              'الدورة الحالية: ${_currentPatient.commissionSessionsCount}/${_currentPatient.commissionSessionsTarget} جلسات مكتملة',
                              style: textTheme.bodyMedium,
                            )
                          else if (_currentPatient.commissionCycleState == 'due')
                            Text(
                              'مستحق دفع عمولة بقيمة ${_currentPatient.commissionAmount?.toStringAsFixed(0)} ج.م',
                              style: textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.error,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          else
                            Text(
                              'الدورة الحالية: 0/${_currentPatient.commissionSessionsTarget} جلسات مكتملة',
                              style: textTheme.bodyMedium,
                            ),
                        ],
                      ),
                    ),
                    if (_currentPatient.commissionCycleState == 'due')
                      ElevatedButton(
                        onPressed: () async {
                          final provider = context.read<PatientProvider>();
                          await provider.completeCommissionCycle(_currentPatient);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم تسجيل دفع العمولة بنجاح')),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? AppColors.darkSuccess : AppColors.lightSuccess,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('تم الدفع'),
                      ),
                  ],
                ),
            ),
          ],

          // ── Sessions Section Header ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'سجل الجلسات (${sessions.length})',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (!_currentPatient.treatmentEnded)
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.addSession,
                        arguments: _currentPatient.id,
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('إضافة جلسة'),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  onPressed: _toggleTreatmentEnded,
                  icon: Icon(
                    _currentPatient.treatmentEnded
                        ? Icons.refresh
                        : Icons.check_circle_outline,
                  ),
                  label: Text(
                    _currentPatient.treatmentEnded
                        ? 'إعادة تفعيل العلاج'
                        : 'إنهاء العلاج',
                  ),
                ),
                TextButton(
                  onPressed: _deletePatient,
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                  child: const Text('حذف نهائي'),
                ),
              ],
            ),
          ),

          // ── Sessions List ──────────────────────────────────────────────────
          Expanded(
            child: Consumer<SessionProvider>(
              builder: (context, sessionProvider, child) {
                if (sessionProvider.isLoading) {
                  return const LoadingWidget(message: 'جاري تحميل الجلسات...');
                }

                if (sessionProvider.error != null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'حدث خطأ أثناء تحميل الجلسات: ${sessionProvider.error}',
                        style: textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  );
                }

                if (sessions.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_note,
                          size: 48,
                          color: theme.colorScheme.primary.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'لا يوجد جلسات مسجلة لهذا المريض',
                          style: textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: sessions.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final session = sessions[index];
                    return SessionCard(
                      session: session,
                      patientName: _currentPatient.name,
                      patientPhone: _currentPatient.phone,
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
