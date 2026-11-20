import 'package:flutter/material.dart';
import 'package:physical_therapy/core/services/migration_service.dart';
import 'package:physical_therapy/widgets/custom_button.dart';

class MigrationScreen extends StatefulWidget {
  final VoidCallback onMigrationSuccess;

  const MigrationScreen({super.key, required this.onMigrationSuccess});

  @override
  State<MigrationScreen> createState() => _MigrationScreenState();
}

class _MigrationScreenState extends State<MigrationScreen> {
  final MigrationService _migrationService = MigrationService();

  String _statusMessage = 'جاري نقل بياناتك إلى الحساب الجديد…';
  double _progress = 0.0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startMigration();
  }

  Future<void> _startMigration() async {
    setState(() {
      _error = null;
      _statusMessage = 'جاري نقل بياناتك إلى الحساب الجديد…';
      _progress = 0.05;
    });

    try {
      await _migrationService.runMigration(
        onProgress: (message, progress) {
          if (mounted) {
            setState(() {
              _statusMessage = message;
              _progress = progress;
            });
          }
        },
      );

      if (mounted) {
        widget.onMigrationSuccess();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('StateError: ', '').replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.sync,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'جاري نقل بياناتك إلى الحساب الجديد…',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.error.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      _error!,
                      style: textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),
                  CustomButton(
                    text: 'إعادة المحاولة',
                    icon: Icons.refresh,
                    onPressed: _startMigration,
                  ),
                ] else ...[
                  LinearProgressIndicator(
                    value: _progress > 0 ? _progress : null,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _statusMessage,
                    style: textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
