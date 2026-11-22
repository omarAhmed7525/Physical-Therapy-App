import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:physical_therapy/core/services/reminder_service.dart';
import 'package:physical_therapy/core/theme/theme_provider.dart';
import 'package:provider/provider.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  void _showEditNameDialog(BuildContext context, User user) {
    final controller = TextEditingController(text: user.displayName ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        bool isLoading = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('تعديل الاسم'),
              content: Form(
                key: formKey,
                child: TextFormField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'الاسم',
                    hintText: 'أدخل اسم الطبيب',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().length < 2) {
                      return 'يرجى إدخال اسم صحيح (حرفين على الأقل)';
                    }
                    return null;
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() {
                            isLoading = true;
                          });
                          try {
                            await user.updateDisplayName(controller.text.trim());
                            await user.reload();
                            if (mounted) {
                              setState(() {});
                            }
                            if (context.mounted) {
                              Navigator.pop(dialogCtx);
                            }
                          } catch (e) {
                            setDialogState(() {
                              isLoading = false;
                            });
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('حدث خطأ أثناء حفظ الاسم: $e')),
                              );
                            }
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('حفظ'),
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
    final themeProvider = context.watch<ThemeProvider>();
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName?.trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // ── Appearance Section ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(right: 8.0, bottom: 8.0),
            child: Text(
              'المظهر',
              style: textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Card(
            child: SwitchListTile(
              secondary: Icon(
                themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                color: theme.colorScheme.primary,
              ),
              title: const Text(
                'الوضع الداكن (Dark Mode)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                themeProvider.isDarkMode
                    ? 'تفعيل المظهر الليلي المريح للعينين'
                    : 'تفعيل المظهر النهاري المضيء',
                style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
              ),
              value: themeProvider.isDarkMode,
              onChanged: (bool value) {
                themeProvider.toggleTheme();
              },
            ),
          ),
          const SizedBox(height: 24),

          // ── Reminders Section ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(right: 8.0, bottom: 8.0),
            child: Text(
              'التذكيرات',
              style: textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Card(
            child: SwitchListTile(
              secondary: Icon(
                Icons.notifications_active_outlined,
                color: theme.colorScheme.primary,
              ),
              title: const Text(
                'تذكيرات الجلسات',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'إشعار تنبيه قبل موعد الجلسة المحجوزة بـ 30 دقيقة',
                style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
              ),
              value: ReminderService().notificationsEnabled,
              onChanged: (bool value) {
                setState(() {
                  ReminderService().setNotificationsEnabled(value);
                });
              },
            ),
          ),
          const SizedBox(height: 24),

          // ── App Info Section ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(right: 8.0, bottom: 8.0),
            child: Text(
              'عن التطبيق',
              style: textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'إصدار التطبيق',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '1.0.0',
                        style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'نوع الاستخدام',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'طبيب منفرد (عيادة خاصة)',
                        style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── Account Section ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(right: 8.0, bottom: 8.0),
            child: Text(
              'الحساب',
              style: textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Card(
            child: Column(
              children: [
                if (user != null) ...[
                  ListTile(
                    leading: Icon(
                      Icons.person,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                    title: const Text(
                      'الاسم',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      displayName != null && displayName.isNotEmpty
                          ? displayName
                          : 'لم يتم إضافة اسم',
                      style: TextStyle(
                        color: displayName != null && displayName.isNotEmpty
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      tooltip: 'تعديل الاسم',
                      onPressed: () => _showEditNameDialog(context, user),
                    ),
                  ),
                  const Divider(height: 1),
                ],
                ListTile(
                  leading: Icon(
                    Icons.logout,
                    color: theme.colorScheme.error,
                    size: 24,
                  ),
                  title: Text(
                    'تسجيل الخروج',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.error,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الخروج من حساب الطبيب',
                        style: textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      if (user?.email != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          user!.email!,
                          style: textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                  onTap: () async {
                    await ReminderService().cancelAll();
                    await FirebaseAuth.instance.signOut();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
