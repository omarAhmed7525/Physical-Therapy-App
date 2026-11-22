import 'package:flutter/material.dart';
import 'package:physical_therapy/app/routes.dart';
import 'package:physical_therapy/core/constants/app_colors.dart';
import 'package:physical_therapy/core/utils/debt_calculator.dart';
import 'package:physical_therapy/models/patient_model.dart';
import 'package:physical_therapy/providers/debt_provider.dart';
import 'package:physical_therapy/providers/patient_provider.dart';
import 'package:physical_therapy/providers/session_provider.dart';
import 'package:physical_therapy/widgets/custom_textfield.dart';
import 'package:provider/provider.dart';

class DebtsView extends StatelessWidget {
  const DebtsView({super.key});

  void _showPaymentDialog(
    BuildContext context, {
    required PatientModel patient,
    required double outstanding,
  }) {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController();
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        bool isSubmitting = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            return AlertDialog(
              title: Text('سداد دفعة — ${patient.name}'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'إجمالي المديونية الحالية: ${outstanding.toStringAsFixed(0)} ج.م',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: amountController,
                        label: 'المبلغ المدفوع *',
                        hint: 'أدخل المبلغ',
                        prefixIcon: Icons.payment,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'يرجى إدخال المبلغ';
                          }
                          final parsed = double.tryParse(value.trim());
                          if (parsed == null || parsed <= 0) {
                            return 'يرجى إدخال مبلغ صحيح أكبر من صفر';
                          }
                          if (parsed > outstanding) {
                            return 'المبلغ يتجاوز إجمالي المديونية (${outstanding.toStringAsFixed(0)} ج.م)';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      CustomTextField(
                        controller: noteController,
                        label: 'ملاحظة (اختياري)',
                        hint: 'مثال: دفعة عبر فودافون كاش',
                        prefixIcon: Icons.notes,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          final amount = double.parse(amountController.text.trim());
                          final note = noteController.text.trim();

                          setDialogState(() {
                            isSubmitting = true;
                          });

                          try {
                            await context.read<DebtProvider>().addPayment(
                              patientId: patient.id,
                              amount: amount,
                              note: note.isNotEmpty ? note : null,
                            );

                            if (context.mounted) {
                              Navigator.pop(dialogCtx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('تم تسجيل سداد الدفعة بنجاح')),
                              );
                            }
                          } catch (e) {
                            setDialogState(() {
                              isSubmitting = false;
                            });
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('حدث خطأ أثناء السداد: $e'),
                                  backgroundColor: theme.colorScheme.error,
                                ),
                              );
                            }
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('تأكيد السداد'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;

    final patientProvider = context.watch<PatientProvider>();
    final sessionProvider = context.watch<SessionProvider>();
    final debtProvider = context.watch<DebtProvider>();

    final patients = patientProvider.patients;
    final sessions = sessionProvider.sessions;
    final debtPayments = debtProvider.debtPayments;

    // Calculate outstanding per patient and keep those with debt > 0
    final List<({PatientModel patient, double outstanding})> debtorList = [];
    double totalOutstandingAll = 0.0;

    for (final patient in patients) {
      final out = DebtCalculator.calculateOutstandingDebt(
        patientId: patient.id,
        sessions: sessions,
        debtPayments: debtPayments,
      );
      totalOutstandingAll += out;
      if (out > 0) {
        debtorList.add((patient: patient, outstanding: out));
      }
    }

    // Sort descending by outstanding amount
    debtorList.sort((a, b) => b.outstanding.compareTo(a.outstanding));

    return Scaffold(
      appBar: AppBar(
        title: const Text('المديونيات'),
      ),
      body: Column(
        children: [
          // ── Header Summary Card ────────────────────────────────────────────
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16.0),
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.dividerColor.withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'إجمالي المديونيات المستحقة',
                      style: textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      color: isDark ? AppColors.darkError : AppColors.lightError,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${totalOutstandingAll.toStringAsFixed(0)} ج.م',
                  style: textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkError : AppColors.lightError,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'عدد المرضى المدينين: ${debtorList.length}',
                  style: textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),

          // ── Debtors List ───────────────────────────────────────────────────
          Expanded(
            child: debtorList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 64,
                          color: (isDark ? AppColors.darkSuccess : AppColors.lightSuccess).withValues(alpha: 0.6),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'لا توجد مديونيات معلقة حالياً',
                          style: textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    itemCount: debtorList.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = debtorList[index];
                      return Card(
                        child: InkWell(
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              AppRoutes.patientDetails,
                              arguments: item.patient,
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                                  child: Icon(
                                    Icons.person,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.patient.name,
                                        style: textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'متبقي: ${item.outstanding.toStringAsFixed(0)} ج.م',
                                        style: textTheme.bodyMedium?.copyWith(
                                          color: isDark ? AppColors.darkError : AppColors.lightError,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    _showPaymentDialog(
                                      context,
                                      patient: item.patient,
                                      outstanding: item.outstanding,
                                    );
                                  },
                                  icon: const Icon(Icons.payment, size: 16),
                                  label: const Text('سداد دفعة'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
