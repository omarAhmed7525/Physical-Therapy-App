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
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    _latController.dispose();
    _lngController.dispose();
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
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
