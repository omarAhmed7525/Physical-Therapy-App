import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:physical_therapy/core/theme/theme_provider.dart';
import 'package:provider/provider.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final themeProvider = context.watch<ThemeProvider>();

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
                style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6)),
              ),
              value: themeProvider.isDarkMode,
              onChanged: (bool value) {
                themeProvider.toggleTheme();
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
                        style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6)),
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
                        style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6)),
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
            child: ListTile(
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: theme.colorScheme.error.withOpacity(0.12),
                child: Icon(
                  Icons.logout,
                  color: theme.colorScheme.error,
                  size: 20,
                ),
              ),
              title: Text(
                'تسجيل الخروج',
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.error,
                ),
              ),
              subtitle: Text(
                'الخروج من حساب الطبيب',
                style: textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                // AuthGate's StreamBuilder reacts to authStateChanges automatically.
                // No manual navigation is needed here.
              },
            ),
          ),
        ],
      ),
    );
  }
}
