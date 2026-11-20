import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:physical_therapy/models/patient_model.dart';
import 'package:physical_therapy/providers/patient_provider.dart';
import 'package:physical_therapy/widgets/custom_button.dart';
import 'package:physical_therapy/widgets/custom_textfield.dart';
import 'package:provider/provider.dart';

class EditPatientView extends StatefulWidget {
  final PatientModel patient;

  const EditPatientView({super.key, required this.patient});

  @override
  State<EditPatientView> createState() => _EditPatientViewState();
}

class _EditPatientViewState extends State<EditPatientView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _notesController;
  late final TextEditingController _latController;
  late final TextEditingController _lngController;

  late bool _commissionEnabled;
  late final TextEditingController _commissionAmountController;

  late bool _planEnabled;
  late final TextEditingController _planTotalSessionsController;
  bool _resetPlanStartDate = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.patient.name);
    _phoneController = TextEditingController(text: widget.patient.phone);
    _addressController = TextEditingController(text: widget.patient.address);
    _notesController = TextEditingController(text: widget.patient.medicalNotes);
    _latController = TextEditingController(
      text: widget.patient.location != null
          ? widget.patient.location!.latitude.toString()
          : '',
    );
    _lngController = TextEditingController(
      text: widget.patient.location != null
          ? widget.patient.location!.longitude.toString()
          : '',
    );
    _commissionEnabled = widget.patient.commissionEnabled;
    _commissionAmountController = TextEditingController(
      text: widget.patient.commissionAmount != null
          ? widget.patient.commissionAmount!.toString()
          : '',
    );
    _planEnabled = widget.patient.planTotalSessions != null;
    _planTotalSessionsController = TextEditingController(
      text: widget.patient.planTotalSessions != null
          ? widget.patient.planTotalSessions!.toString()
          : '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _commissionAmountController.dispose();
    _planTotalSessionsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final address = _addressController.text.trim();
    final notes = _notesController.text.trim();

    double? lat;
    double? lng;
    bool clearLocation = false;

    if (_latController.text.isEmpty || _lngController.text.isEmpty) {
      if (address.isNotEmpty) {
        // Auto-geocode the address if lat/lng were not entered manually.
        try {
          final locations = await locationFromAddress(address);
          if (locations.isNotEmpty) {
            lat = locations.first.latitude;
            lng = locations.first.longitude;
          } else {
            clearLocation = true;
          }
        } catch (_) {
          clearLocation = true;
        }
      } else {
        // Address is empty — clear the stored location.
        clearLocation = true;
      }
    } else {
      lat = double.tryParse(_latController.text.trim());
      lng = double.tryParse(_lngController.text.trim());
      if (lat == null || lng == null) {
        clearLocation = true;
      }
    }

    final provider = context.read<PatientProvider>();
    await provider.updatePatient(
      widget.patient,
      name: name,
      phone: phone,
      address: address,
      medicalNotes: notes,
      latitude: lat,
      longitude: lng,
      clearLocation: clearLocation,
      commissionEnabled: _commissionEnabled,
      commissionAmount: _commissionEnabled ? double.tryParse(_commissionAmountController.text.trim()) : null,
      planTotalSessions: _planEnabled ? int.tryParse(_planTotalSessionsController.text.trim()) : null,
      resetPlanStartDate: _resetPlanStartDate,
      clearPlan: !_planEnabled,
    );

    if (mounted) {
      if (provider.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء تعديل بيانات المريض: ${provider.error}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تعديل بيانات المريض بنجاح'),
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<PatientProvider>().isLoading;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('تعديل بيانات المريض'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            CustomTextField(
              controller: _nameController,
              label: 'اسم المريض *',
              hint: 'أدخل اسم المريض الثنائي أو الثلاثي',
              prefixIcon: Icons.person,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'يرجى إدخال اسم المريض';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _phoneController,
              label: 'رقم الهاتف',
              hint: 'أدخل رقم الهاتف المكون من 10 أرقام (اختياري)',
              prefixIcon: Icons.phone,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _addressController,
              label: 'العنوان بالتفصيل',
              hint: 'المحافظة، المدينة، الشارع، علامة مميزة (اختياري)',
              prefixIcon: Icons.location_city,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    controller: _latController,
                    label: 'خط العرض (Latitude)',
                    hint: 'مثال: 30.0444',
                    prefixIcon: Icons.map,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: CustomTextField(
                    controller: _lngController,
                    label: 'خط الطول (Longitude)',
                    hint: 'مثال: 31.2357',
                    prefixIcon: Icons.map,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'امسح القيمتين أعلاه إذا كنت تريد إلغاء الموقع الجغرافي للمريض.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _notesController,
              label: 'التشخيص الطبي / ملاحظات طبية',
              hint: 'اكتب الحالة المرضية للمريض والتشخيص المبدئي...',
              prefixIcon: Icons.medical_services,
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('باقة علاج'),
                    subtitle: const Text('تحديد عدد جلسات محدد كباقة للمريض'),
                    value: _planEnabled,
                    onChanged: (val) {
                      setState(() {
                        _planEnabled = val;
                      });
                    },
                    secondary: Icon(
                      Icons.inventory_2_outlined,
                      color: _planEnabled ? theme.colorScheme.primary : theme.disabledColor,
                    ),
                  ),
                  if (_planEnabled) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: CustomTextField(
                        controller: _planTotalSessionsController,
                        label: 'عدد جلسات الباقة *',
                        hint: 'مثال: 12',
                        prefixIcon: Icons.format_list_numbered,
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (_planEnabled) {
                            if (value == null || value.trim().isEmpty) {
                              return 'يرجى إدخال عدد الجلسات';
                            }
                            final count = int.tryParse(value.trim());
                            if (count == null || count < 1) {
                              return 'يرجى إدخال عدد صحيح أكبر من أو يساوي 1';
                            }
                          }
                          return null;
                        },
                      ),
                    ),
                    CheckboxListTile(
                      title: const Text('بدء باقة جديدة من اليوم'),
                      subtitle: const Text('إعادة ضبط تاريخ بدء الباقة وحساب الجلسات من جديد'),
                      value: _resetPlanStartDate,
                      onChanged: (val) {
                        setState(() {
                          _resetPlanStartDate = val ?? false;
                        });
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('تفعيل تتبع العمولة'),
                    subtitle: const Text('احتساب عمولة لجهة الإحالة عند اكتمال 3 جلسات'),
                    value: _commissionEnabled,
                    onChanged: (val) {
                      setState(() {
                        _commissionEnabled = val;
                      });
                    },
                    secondary: Icon(
                      Icons.monetization_on,
                      color: _commissionEnabled ? theme.colorScheme.primary : theme.disabledColor,
                    ),
                  ),
                  if (_commissionEnabled)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: CustomTextField(
                        controller: _commissionAmountController,
                        label: 'قيمة العمولة كل 3 جلسات',
                        hint: 'أدخل قيمة العمولة بالجنيه',
                        prefixIcon: Icons.attach_money,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          if (_commissionEnabled) {
                            if (value == null || value.trim().isEmpty) {
                              return 'يرجى إدخال قيمة العمولة';
                            }
                            final amount = double.tryParse(value.trim());
                            if (amount == null || amount <= 0) {
                              return 'يرجى إدخال رقم صحيح أكبر من الصفر';
                            }
                          }
                          return null;
                        },
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 32),
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
