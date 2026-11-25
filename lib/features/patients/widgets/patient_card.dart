import 'package:flutter/material.dart';
import 'package:physical_therapy/core/constants/app_colors.dart';
import 'package:physical_therapy/core/utils/plan_calculator.dart';
import 'package:physical_therapy/models/patient_model.dart';
import 'package:physical_therapy/providers/session_provider.dart';
import 'package:physical_therapy/widgets/gradient_card.dart';
import 'package:provider/provider.dart';

class PatientCard extends StatelessWidget {
  final PatientModel patient;
  final VoidCallback onTap;

  const PatientCard({
    super.key,
    required this.patient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;

    final sessions = context.watch<SessionProvider>().sessions;
    final planState = PlanCalculator.getPlanState(
      patient: patient,
      sessions: sessions,
    );

    return GradientCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16.0),
      child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            patient.name,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (patient.commissionEnabled && patient.commissionCycleState != 'inactive') ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: patient.commissionCycleState == 'due'
                                  ? (isDark ? AppColors.darkError : AppColors.lightError)
                                  : (isDark ? AppColors.darkWarning : AppColors.lightWarning),
                            ),
                          ),
                        ],
                        if (patient.treatmentEnded) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDark ? AppColors.darkSuccess : AppColors.lightSuccess,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (isDark ? AppColors.darkSuccess : AppColors.lightSuccess)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: (isDark ? AppColors.darkSuccess : AppColors.lightSuccess)
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                            child: Text(
                              'منتهي',
                              style: textTheme.labelSmall?.copyWith(
                                color: isDark ? AppColors.darkSuccess : AppColors.lightSuccess,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                        // Treatment Plan status chip (Workstream C4)
                        if (planState == PlanState.low) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (isDark ? AppColors.darkWarning : AppColors.lightWarning)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: (isDark ? AppColors.darkWarning : AppColors.lightWarning)
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                            child: Text(
                              'قاربت الباقة على الانتهاء',
                              style: textTheme.labelSmall?.copyWith(
                                color: isDark ? AppColors.darkWarning : AppColors.lightWarning,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ] else if (planState == PlanState.finished) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (isDark ? AppColors.darkError : AppColors.lightError)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: (isDark ? AppColors.darkError : AppColors.lightError)
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                            child: Text(
                              'انتهت الباقة',
                              style: textTheme.labelSmall?.copyWith(
                                color: isDark ? AppColors.darkError : AppColors.lightError,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.phone,
                    size: 16,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    patient.phone,
                    style: textTheme.bodyMedium,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 16,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      patient.address.isNotEmpty ? patient.address : 'لا يوجد عنوان مسجل',
                      style: textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (patient.medicalNotes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.dividerColor.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ملاحظات طبية:',
                        style: textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        patient.medicalNotes,
                        style: textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
    );
  }
}
