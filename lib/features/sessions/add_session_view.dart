import 'package:flutter/material.dart';
import 'package:physical_therapy/core/constants/app_colors.dart';
import 'package:physical_therapy/core/services/reminder_service.dart';
import 'package:physical_therapy/core/utils/date_helper.dart';
import 'package:physical_therapy/core/utils/plan_calculator.dart';
import 'package:physical_therapy/models/session_model.dart';
import 'package:physical_therapy/providers/patient_provider.dart';
import 'package:physical_therapy/providers/session_provider.dart';
import 'package:physical_therapy/widgets/custom_button.dart';
import 'package:physical_therapy/widgets/custom_textfield.dart';
import 'package:physical_therapy/widgets/duration_field.dart';
import 'package:provider/provider.dart';

/// Arguments for opening the Add Session view.
/// Can be opened with just a [patientId] or with an [initialDateTime].
class AddSessionArgs {
  final String? patientId;
  final DateTime? initialDateTime;

  const AddSessionArgs({this.patientId, this.initialDateTime});
}

class AddSessionView extends StatefulWidget {
  final String? patientId;
  final DateTime? initialDateTime;

  const AddSessionView({
    super.key,
    this.patientId,
    this.initialDateTime,
  });

  @override
  State<AddSessionView> createState() => _AddSessionViewState();
}

class _AddSessionViewState extends State<AddSessionView> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedPatientId;
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  final _timeController = TextEditingController();
  final _priceController = TextEditingController();
  final _paidController = TextEditingController();
  final _notesController = TextEditingController();

  int _selectedDurationMinutes = 60;
  late SessionStatus _selectedStatus;
  bool _userManuallyChangedStatus = false;

  @override
  void initState() {
    super.initState();
    _selectedPatientId = widget.patientId;

    final initial = widget.initialDateTime ?? DateTime.now();
    _selectedDate = DateTime(initial.year, initial.month, initial.day);
    _selectedTime = TimeOfDay(hour: initial.hour, minute: initial.minute);

    // Initial default status: scheduled if future, otherwise completed
    final fullDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
    _selectedStatus = fullDateTime.isAfter(DateTime.now())
        ? SessionStatus.scheduled
        : SessionStatus.completed;

    _updateTimeControllerText();
  }

  void _updateTimeControllerText() {
    final dt = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
    _timeController.text = DateHelper.formatTime(dt);
  }

  void _checkAutoStatus() {
    if (_userManuallyChangedStatus) return;
    final fullDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
    final autoStatus = fullDateTime.isAfter(DateTime.now())
        ? SessionStatus.scheduled
        : SessionStatus.completed;
    if (_selectedStatus != autoStatus) {
      setState(() {
        _selectedStatus = autoStatus;
      });
    }
  }

  @override
  void dispose() {
    _timeController.dispose();
    _priceController.dispose();
    _paidController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _checkAutoStatus();
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
        _updateTimeControllerText();
        _checkAutoStatus();
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPatientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى تحديد المريض أولاً')),
      );
      return;
    }

    final price = double.tryParse(_priceController.text.trim()) ?? 0.0;
    final paid = double.tryParse(_paidController.text.trim()) ?? 0.0;

    final fullScheduledDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final sessionProvider = context.read<SessionProvider>();
    final newSessionId = await sessionProvider.addSession(
      patientId: _selectedPatientId!,
      date: fullScheduledDateTime,
      durationMinutes: _selectedDurationMinutes,
      price: price,
      paidAmount: paid,
      status: _selectedStatus,
      notes: _notesController.text.trim(),
    );

    if (mounted) {
      if (sessionProvider.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(sessionProvider.error!),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تسجيل الجلسة بنجاح')),
        );

        // Schedule reminder notification if status is scheduled
        if (_selectedStatus == SessionStatus.scheduled) {
          final patientProvider = context.read<PatientProvider>();
          final patient = patientProvider.patients.cast<dynamic>().firstWhere(
                (p) => p.id == _selectedPatientId,
                orElse: () => null,
              );
          final pName = patient?.name ?? 'المريض';
          final sId = newSessionId ?? fullScheduledDateTime.millisecondsSinceEpoch.toString();
          await ReminderService().scheduleSessionReminder(
            sessionId: sId,
            patientName: pName,
            sessionDate: fullScheduledDateTime,
          );
        }

        // Check if plan state is low or finished after completed session (Workstream C4)
        if (_selectedStatus == SessionStatus.completed) {
          final patientProvider = context.read<PatientProvider>();
          final patients = patientProvider.patients;
          final matchingPatients = patients.where((p) => p.id == _selectedPatientId).toList();
          final patient = matchingPatients.isNotEmpty ? matchingPatients.first : null;
          if (patient != null &&
              patient.planTotalSessions != null &&
              patient.planStartDate != null) {
            final remaining = PlanCalculator.calculateRemainingSessions(
              patient: patient,
              sessions: sessionProvider.sessions,
            );
            if (remaining == 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('انتهت الباقة'),
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
              );
            } else if (remaining <= kPlanLowThreshold) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('قاربت الباقة على الانتهاء'),
                  backgroundColor: isDark ? AppColors.darkWarning : AppColors.lightWarning,
                ),
              );
            }
          }
        }

        FocusManager.instance.primaryFocus?.unfocus();
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final patients = context.watch<PatientProvider>().patients;

    final fixedPatient = widget.patientId != null
        ? patients.cast<dynamic>().firstWhere(
              (p) => p.id == widget.patientId,
              orElse: () => null,
            )
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('إضافة جلسة جديدة'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Patient Selection ──────────────────────────────────────────
              if (fixedPatient != null)
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.person, color: theme.colorScheme.primary),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'المريض المحدد:',
                            style: textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            fixedPatient.name,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: _selectedPatientId,
                  decoration: const InputDecoration(
                    labelText: 'اختر المريض *',
                    prefixIcon: Icon(Icons.person),
                  ),
                  items: patients.map((patient) {
                    return DropdownMenuItem<String>(
                      value: patient.id,
                      child: Text(patient.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedPatientId = value;
                    });
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'يرجى اختيار مريض';
                    }
                    return null;
                  },
                ),
              const SizedBox(height: 16),

              // ── Date and Time Selection ────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _selectDate,
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'التاريخ *',
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          DateHelper.formatDate(_selectedDate),
                          style: textTheme.bodyMedium,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: _selectTime,
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'الوقت *',
                          prefixIcon: Icon(Icons.access_time),
                        ),
                        child: Text(
                          _timeController.text,
                          style: textTheme.bodyMedium,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Duration Field ─────────────────────────────────────────────
              DurationField(
                initialValue: _selectedDurationMinutes,
                onChanged: (value) {
                  _selectedDurationMinutes = value;
                },
              ),
              const SizedBox(height: 16),

              // ── Financial Info ─────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: _priceController,
                      label: 'سعر الجلسة *',
                      hint: 'مثال: 200',
                      prefixIcon: Icons.attach_money,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'يرجى إدخال السعر';
                        }
                        if (double.tryParse(value) == null) {
                          return 'سعر غير صالح';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CustomTextField(
                      controller: _paidController,
                      label: 'المبلغ المدفوع *',
                      hint: 'مثال: 100',
                      prefixIcon: Icons.payment,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'يرجى إدخال المدفوع';
                        }
                        if (double.tryParse(value) == null) {
                          return 'مبلغ غير صالح';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Status Selection ───────────────────────────────────────────
              DropdownButtonFormField<SessionStatus>(
                key: ValueKey(_selectedStatus),
                initialValue: _selectedStatus,
                decoration: const InputDecoration(
                  labelText: 'حالة الجلسة *',
                  prefixIcon: Icon(Icons.info_outline),
                ),
                items: SessionStatus.values.map((status) {
                  return DropdownMenuItem<SessionStatus>(
                    value: status,
                    child: Text(status.arabicLabel),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedStatus = value;
                      _userManuallyChangedStatus = true;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              // ── Notes ──────────────────────────────────────────────────────
              CustomTextField(
                controller: _notesController,
                label: 'ملاحظات وتفاصيل الجلسة',
                hint: 'اكتب التمارين التي تم إجراؤها أو الملاحظات الطبية...',
                prefixIcon: Icons.description,
                maxLines: 3,
              ),
              const SizedBox(height: 24),

              // ── Submit Button ──────────────────────────────────────────────
              Consumer<SessionProvider>(
                builder: (context, provider, _) {
                  return CustomButton(
                    text: 'حفظ الجلسة',
                    icon: Icons.check,
                    isLoading: provider.isLoading,
                    onPressed: _submit,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
