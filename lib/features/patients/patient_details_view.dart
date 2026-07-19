import 'package:flutter/material.dart';
import 'package:physical_therapy/app/routes.dart';
import 'package:physical_therapy/core/services/maps_service.dart';
import 'package:physical_therapy/features/sessions/widgets/session_card.dart';
import 'package:physical_therapy/models/patient_model.dart';
import 'package:physical_therapy/providers/patient_provider.dart';
import 'package:physical_therapy/providers/session_provider.dart';
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
        const SnackBar(content: Text('تعذر فتح خرائط جوجل')),
      );
    }
  }

  Future<void> _deletePatient() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المريض'),
        content: Text('هل أنت متأكد من حذف المريض ${_currentPatient.name}؟ سيؤدي ذلك إلى حذف بياناته بالكامل.'),
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
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final patientProvider = context.read<PatientProvider>();
      await patientProvider.deletePatient(_currentPatient.id);

      if (mounted) {
        if (patientProvider.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('حدث خطأ أثناء الحذف: ${patientProvider.error}'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حذف المريض بنجاح')),
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

    // Listen to changes in the patient provider to keep this view updated if patient is edited.
    final updatedPatients = context.watch<PatientProvider>().patients;
    final index = updatedPatients.indexWhere((p) => p.id == _currentPatient.id);
    if (index != -1) {
      _currentPatient = updatedPatients[index];
    }

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
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'حذف المريض',
            onPressed: _deletePatient,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Patient Info Card ──────────────────────────────────────────────
          Card(
            margin: const EdgeInsets.all(16.0),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
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
                              'رقم الهاتف: ${_currentPatient.phone}',
                              style: textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(color: theme.dividerColor.withOpacity(0.3)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 20,
                        color: theme.colorScheme.secondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _currentPatient.address,
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
                      if (_currentPatient.location != null) ...[
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _openLocation,
                            icon: const Icon(Icons.map),
                            label: const Text('الموقع الجغرافي'),
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
          ),

          if (_currentPatient.commissionEnabled) ...[
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: _currentPatient.commissionCycleState == 'due'
                          ? theme.colorScheme.error.withOpacity(0.12)
                          : Colors.amber.withOpacity(0.12),
                      child: Icon(
                        Icons.monetization_on,
                        color: _currentPatient.commissionCycleState == 'due'
                            ? theme.colorScheme.error
                            : Colors.amber,
                      ),
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
                              'الدورة الحالية: ${_currentPatient.commissionSessionsCount}/3 جلسات مكتملة',
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
                              'الدورة الحالية: 0/3 جلسات مكتملة',
                              style: textTheme.bodyMedium,
                            ),
                        ],
                      ),
                    ),
                    if (_currentPatient.commissionCycleState == 'due')
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.error,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          minimumSize: Size.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('تأكيد دفع العمولة'),
                              content: Text('هل تم دفع عمولة بقيمة ${_currentPatient.commissionAmount?.toStringAsFixed(0)} جنيه للجهة المحيلة؟'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('إلغاء'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: TextButton.styleFrom(
                                    foregroundColor: theme.colorScheme.error,
                                  ),
                                  child: const Text('تأكيد الدفع'),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true && mounted) {
                            final patientProvider = context.read<PatientProvider>();
                            await patientProvider.completeCommissionCycle(_currentPatient);
                            if (mounted) {
                              if (patientProvider.error != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('حدث خطأ: ${patientProvider.error}'),
                                    backgroundColor: theme.colorScheme.error,
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('تم تسجيل دفع العمولة وتصفير الدورة بنجاح'),
                                  ),
                                );
                              }
                            }
                          }
                        },
                        child: const Text('تم الدفع'),
                      )
                    else if (_currentPatient.commissionCycleState == 'inProgress')
                      Chip(
                        backgroundColor: Colors.amber.withOpacity(0.12),
                        side: const BorderSide(color: Colors.amber),
                        label: Text(
                          '${_currentPatient.commissionSessionsCount}/3 جلسات',
                          style: const TextStyle(
                            color: Colors.amber,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else
                      Chip(
                        backgroundColor: theme.dividerColor.withOpacity(0.12),
                        side: BorderSide(color: theme.dividerColor),
                        label: const Text(
                          '0/3 جلسات',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],

          // ── Sessions Header ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'الجلسات العلاجية',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
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

                final sessions = sessionProvider.patientSessions(_currentPatient.id);

                if (sessions.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_note,
                          size: 48,
                          color: theme.colorScheme.primary.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'لا يوجد جلسات مسجلة لهذا المريض',
                          style: textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
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
                    return SessionCard(session: session);
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