import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:physical_therapy/models/patient_model.dart';
import 'package:physical_therapy/models/session_model.dart';
import 'package:physical_therapy/providers/patient_provider.dart';
import 'package:physical_therapy/providers/session_provider.dart';
import 'package:physical_therapy/widgets/custom_button.dart';
import 'package:physical_therapy/widgets/custom_textfield.dart';
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
  late final TextEditingController _timeController;
  late final TextEditingController _priceController;
  late final TextEditingController _paidController;
  late final TextEditingController _notesController;
  late SessionStatus _selectedStatus;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.session.date;
    _timeController = TextEditingController(text: widget.session.time);
    _priceController = TextEditingController(text: widget.session.price.toStringAsFixed(0));
    _paidController = TextEditingController(text: widget.session.paidAmount.toStringAsFixed(0));
    _notesController = TextEditingController(text: widget.session.notes);
    _selectedStatus = widget.session.status;
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
      initialTime: TimeOfDay.fromDateTime(widget.session.date),
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

    final price = double.tryParse(_priceController.text.trim()) ?? 0.0;
    final paid = double.tryParse(_paidController.text.trim()) ?? 0.0;

    final sessionProvider = context.read<SessionProvider>();
    await sessionProvider.updateSession(
      widget.session,
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
            content: Text('حدث خطأ أثناء تعديل الجلسة: ${sessionProvider.error}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تعديل الجلسة بنجاح')),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _deleteSession() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الجلسة'),
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

    if (confirm == true && mounted) {
      final sessionProvider = context.read<SessionProvider>();
      await sessionProvider.deleteSession(widget.session.patientId, widget.session.id);

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
          Navigator.pop(context);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    final patients = context.watch<PatientProvider>().patients;
    final isLoading = context.watch<SessionProvider>().isLoading;

    final patient = patients.firstWhere(
      (p) => p.id == widget.session.patientId,
      orElse: () => PatientModel(
        id: '',
        name: 'مريض غير معروف',
        phone: '',
        address: '',
        medicalNotes: '',
        createdAt: DateTime.now(),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('تعديل بيانات الجلسة'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'حذف الجلسة',
            onPressed: _deleteSession,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // ── Patient Info Banner ──────────────────────────────────────────
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
                        'اسم المريض:',
                        style: textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        patient.name,
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
              text: 'حفظ التعديلات',
              isLoading: isLoading,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
