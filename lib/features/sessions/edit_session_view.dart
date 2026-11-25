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

class EditSessionView extends StatefulWidget {
  final SessionModel session;

  const EditSessionView({super.key, required this.session});

  @override
  State<EditSessionView> createState() => _EditSessionViewState();
}

class _EditSessionViewState extends State<EditSessionView> {
  final _formKey = GlobalKey<FormState>();

  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  late TextEditingController _timeController;
  late TextEditingController _priceController;
  late TextEditingController _paidController;
  late TextEditingController _notesController;
  late int _selectedDurationMinutes;
  late SessionStatus _selectedStatus;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime(
      widget.session.date.year,
      widget.session.date.month,
      widget.session.date.day,
    );
    _selectedTime = TimeOfDay(
      hour: widget.session.date.hour,
      minute: widget.session.date.minute,
    );
    _selectedDurationMinutes = widget.session.durationMinutes;
    _timeController = TextEditingController(
      text: DateHelper.formatTime(widget.session.date),
    );
    _priceController = TextEditingController(
      text: widget.session.price.toStringAsFixed(0),
    );
    _paidController = TextEditingController(
      text: widget.session.paidAmount.toStringAsFixed(0),
    );
    _notesController = TextEditingController(text: widget.session.notes);
    _selectedStatus = widget.session.status;
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
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

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
    await sessionProvider.updateSession(
      widget.session,
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
          const SnackBar(content: Text('تم تعديل الجلسة بنجاح')),
        );

        // Cancel previous reminder and re-schedule if updated status is scheduled
        await ReminderService().cancelSessionReminder(widget.session.id);
        if (_selectedStatus == SessionStatus.scheduled) {
          final patientProvider = context.read<PatientProvider>();
          final patient = patientProvider.patients.cast<dynamic>().firstWhere(
                (p) => p.id == widget.session.patientId,
                orElse: () => null,
              );
          final pName = patient?.name ?? 'المريض';
          await ReminderService().scheduleSessionReminder(
            sessionId: widget.session.id,
            patientName: pName,
            sessionDate: fullScheduledDateTime,
          );
        }

        // Check if plan state is low or finished after completed session (Workstream C4)
        if (_selectedStatus == SessionStatus.completed) {
          final patientProvider = context.read<PatientProvider>();
          final patients = patientProvider.patients;
          final matchingPatients = patients.where((p) => p.id == widget.session.patientId).toList();
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

  Future<void> _deleteSession() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد من حذف هذه الجلسة نهائياً؟'),
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

    if (confirm != true || !mounted) return;

    final sessionProvider = context.read<SessionProvider>();
    await ReminderService().cancelSessionReminder(widget.session.id);
    await sessionProvider.deleteSession(
      widget.session.patientId,
      widget.session.id,
    );

    if (mounted) {
      if (sessionProvider.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء الحذف: ${sessionProvider.error}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف الجلسة بنجاح')),
        );
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

    final patient = patients.cast<dynamic>().firstWhere(
          (p) => p.id == widget.session.patientId,
          orElse: () => null,
        );
    final patientName = patient?.name ?? 'مريض غير معروف';

    return Scaffold(
      appBar: AppBar(
        title: const Text('تعديل تفاصيل الجلسة'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            color: theme.colorScheme.error,
            tooltip: 'حذف الجلسة',
            onPressed: _deleteSession,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Patient Info Banner ────────────────────────────────────────
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
                          'المريض:',
                          style: textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          patientName,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
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
                    text: 'تعديل وحفظ الجلسة',
                    icon: Icons.save,
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
