import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:physical_therapy/providers/patient_provider.dart';
import 'package:physical_therapy/widgets/custom_button.dart';
import 'package:physical_therapy/widgets/custom_textfield.dart';
import 'package:provider/provider.dart';

class AddPatientView extends StatefulWidget {
  const AddPatientView({super.key});

  @override
  State<AddPatientView> createState() => _AddPatientViewState();
}

class _AddPatientViewState extends State<AddPatientView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  
  bool _commissionEnabled = false;
  final _commissionAmountController = TextEditingController();
  final _commissionTargetController = TextEditingController(text: '3');

  bool _planEnabled = false;
  final _planTotalSessionsController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _commissionAmountController.dispose();
    _commissionTargetController.dispose();
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
    if (_latController.text.isNotEmpty && _lngController.text.isNotEmpty) {
      lat = double.tryParse(_latController.text.trim());
      lng = double.tryParse(_lngController.text.trim());
    } else if (address.isNotEmpty) {
      // Auto-geocode the address if lat/lng were not entered manually.
      try {
        final locations = await locationFromAddress(address);
        if (locations.isNotEmpty) {
          lat = locations.first.latitude;
          lng = locations.first.longitude;
        }
      } catch (_) {
        // Geocoding failed silently; user can still add coordinates manually later.
      }
    }

    final provider = context.read<PatientProvider>();
    await provider.addPatient(
      name: name,
      phone: phone,
      address: address,
      medicalNotes: notes,
      latitude: lat,
      longitude: lng,
      commissionEnabled: _commissionEnabled,
      commissionAmount: _commissionEnabled ? double.tryParse(_commissionAmountController.text.trim()) : null,
      commissionSessionsTarget: _commissionEnabled ? (int.tryParse(_commissionTargetController.text.trim()) ?? 3) : 3,
      planTotalSessions: _planEnabled ? int.tryParse(_planTotalSessionsController.text.trim()) : null,
    );

    if (mounted) {
      if (provider.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء إضافة المريض: ${provider.error}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إضافة المريض بنجاح'),
          ),
        );
        FocusManager.instance.primaryFocus?.unfocus();
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
        title: const Text('إضافة مريض جديد'),
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
              'اختياري: أدخل الإحداثيات لتتمكن من فتح موقع المريض على خرائط جوجل مباشرة من شاشة تفاصيل المريض.',
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
                  if (_planEnabled)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
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
                      child: Column(
                        children: [
                          CustomTextField(
                            controller: _commissionAmountController,
                            label: 'قيمة العمولة',
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
                          const SizedBox(height: 16),
                          CustomTextField(
                            controller: _commissionTargetController,
                            label: 'عدد جلسات العمولة',
                            hint: 'مثال: 3',
                            prefixIcon: Icons.repeat,
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (_commissionEnabled) {
                                final target = int.tryParse(value?.trim() ?? '');
                                if (target == null || target < 1) {
                                  return 'يرجى إدخال عدد جلسات صحيح (1 فأكثر)';
                                }
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            CustomButton(
              text: 'حفظ المريض',
              isLoading: isLoading,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
