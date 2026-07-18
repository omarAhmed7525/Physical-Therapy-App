import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:physical_therapy/models/session_model.dart';
import 'package:physical_therapy/providers/patient_provider.dart';
import 'package:physical_therapy/providers/session_provider.dart';
import 'package:physical_therapy/widgets/custom_button.dart';
import 'package:physical_therapy/widgets/custom_textfield.dart';
import 'package:provider/provider.dart';

class AddSessionView extends StatefulWidget {
  final String? patientId;

  const AddSessionView({super.key, this.patientId});

  @override
  State<AddSessionView> createState() => _AddSessionViewState();
}

class _AddSessionViewState extends State<AddSessionView> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedPatientId;
  DateTime _selectedDate = DateTime.now();
  final _timeController = TextEditingController();
  final _priceController = TextEditingController();
  final _paidController = TextEditingController();
  final _notesController = TextEditingController();
  SessionStatus _selectedStatus = SessionStatus.completed;

  @override
  void initState() {
    super.initState();
    _selectedPatientId = widget.patientId;
    _timeController.text = DateFormat('hh:mm a').format(DateTime.now());
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
      initialTime: TimeOfDay.fromDateTime(DateTime.now()),
    );
    if (picked != null) {
      if (mounted) {
        setState(() {
          _timeController.text = picked.format(context);
        });
      }
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

    final sessionProvider = context.read<SessionProvider>();
    await sessionProvider.addSession(
      patientId: _selectedPatientId!,
      date: _selectedDate,
      time: _timeController.text.trim(),
      price: price,
      paidAmount: paid,
      status: _selectedStatus,
      notes: _notesController.text.trim(),
    );

    if (mounted) {
      if (sessionProvider.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء إضافة الجلسة: ${sessionProvider.error}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تسجيل الجلسة بنجاح')),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    final patients = context.watch<PatientProvider>().patients;
    final isLoading = context.watch<SessionProvider>().isLoading;

    // Find current patient if pre-selected
    final fixedPatient = widget.patientId != null
        ? patients.firstWhere((p) => p.id == widget.patientId, orElse: () => patients.first)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تسجيل جلسة جديدة'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // ── Patient Selection ────────────────────────────────────────────
            if (fixedPatient != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
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
                value: _selectedPatientId,
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

            // ── Date & Time ──────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _selectDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'تاريخ الجلسة *',
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        DateFormat('yyyy/MM/dd').format(_selectedDate),
                        style: textTheme.bodyLarge,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: CustomTextField(
                    controller: _timeController,
                    label: 'وقت الجلسة *',
                    prefixIcon: Icons.access_time,
                    readOnly: true,
                    onTap: _selectTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Price & Paid Amount ──────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    controller: _priceController,
                    label: 'سعر الجلسة *',
                    hint: 'مثال: 150',
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

            // ── Status Selection ─────────────────────────────────────────────
            DropdownButtonFormField<SessionStatus>(
              value: _selectedStatus,
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

            // ── Notes ────────────────────────────────────────────────────────
            CustomTextField(
              controller: _notesController,
              label: 'ملاحظات وتفاصيل الجلسة',
              hint: 'اكتب التمارين التي تم إجراؤها أو الملاحظات الطبية...',
              prefixIcon: Icons.description,
              maxLines: 3,
            ),
            const SizedBox(height: 32),

            // ── Submit Button ────────────────────────────────────────────────
            CustomButton(
              text: 'تسجيل الجلسة',
              isLoading: isLoading,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
