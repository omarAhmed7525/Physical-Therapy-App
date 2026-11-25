import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shared duration input field with quick-pick chips (30, 45, 60, 90)
/// and +/- 5-minute stepper buttons.
class DurationField extends StatefulWidget {
  final int initialValue;
  final ValueChanged<int> onChanged;

  const DurationField({
    super.key,
    required this.initialValue,
    required this.onChanged,
  });

  @override
  State<DurationField> createState() => _DurationFieldState();
}

class _DurationFieldState extends State<DurationField> {
  static const List<int> _quickPicks = [30, 45, 60, 90];
  late final TextEditingController _controller;
  late int _currentValue;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.initialValue;
    _controller = TextEditingController(text: _currentValue.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setValue(int value) {
    final clamped = value.clamp(5, 480);
    setState(() {
      _currentValue = clamped;
      _controller.text = clamped.toString();
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
    });
    widget.onChanged(clamped);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: _controller,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'مدة الجلسة (بالدقائق)',
                  prefixIcon: Icon(Icons.timer_outlined),
                ),
                onChanged: (text) {
                  final parsed = int.tryParse(text.trim());
                  setState(() {
                    _currentValue = parsed ?? 0;
                  });
                  if (parsed != null && parsed >= 5 && parsed <= 480) {
                    widget.onChanged(parsed);
                  }
                },
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'أدخل مدة بين 5 و 480 دقيقة';
                  }
                  final parsed = int.tryParse(value.trim());
                  if (parsed == null || parsed < 5 || parsed > 480) {
                    return 'أدخل مدة بين 5 و 480 دقيقة';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton.outlined(
              onPressed: () => _setValue((_currentValue > 0 ? _currentValue : 60) - 5),
              icon: const Icon(Icons.remove),
              tooltip: 'إنقاص 5 دقائق',
            ),
            const SizedBox(width: 4),
            IconButton.outlined(
              onPressed: () => _setValue((_currentValue > 0 ? _currentValue : 60) + 5),
              icon: const Icon(Icons.add),
              tooltip: 'زيادة 5 دقائق',
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _quickPicks.map((minutes) {
            final isSelected = _currentValue == minutes;
            return ChoiceChip(
              label: Text('$minutes دقيقة'),
              selected: isSelected,
              selectedColor: theme.colorScheme.primary.withValues(alpha: 0.18),
              onSelected: (_) => _setValue(minutes),
            );
          }).toList(),
        ),
      ],
    );
  }
}
