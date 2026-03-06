import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/alarm_item.dart';
import '../services/alarm_service.dart';
import 'circular_time_picker.dart';

class AddAlarmDialog extends StatefulWidget {
  final String? prefillContent;
  const AddAlarmDialog({super.key, this.prefillContent});

  @override
  State<AddAlarmDialog> createState() => _AddAlarmDialogState();
}

class _AddAlarmDialogState extends State<AddAlarmDialog> {
  final AlarmService _alarmService = AlarmService();
  late String alarmContent;
  TimeOfDay? selectedTime;
  RepeatType selectedRepeatType = RepeatType.daily;
  AlarmMode selectedMode = AlarmMode.chaos;
  Set<int> selectedDays = {};

  final List<String> dayNames = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];
  late TextEditingController _contentController;
  late FocusNode _contentFocus;

  @override
  void initState() {
    super.initState();
    alarmContent = widget.prefillContent ?? '';
    _contentController = TextEditingController(text: alarmContent);
    _contentFocus = FocusNode();
  }

  @override
  void dispose() {
    _contentController.dispose();
    _contentFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('New Alarm'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Mode selector ──────────────────────────────────────────
            Text('Mode', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            _ModeSelector(
              selected: selectedMode,
              onChanged: (m) => setState(() => selectedMode = m),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _contentController,
              focusNode: _contentFocus,
              decoration: InputDecoration(
                labelText: 'Label',
                hintText: 'e.g. Take vitamins',
                border: const OutlineInputBorder(),
                suffixIcon: alarmContent.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        tooltip: 'Clear',
                        onPressed: () {
                          setState(() {
                            _contentController.clear();
                            alarmContent = '';
                          });
                          _contentFocus.requestFocus();
                        },
                      )
                    : null,
              ),
              onTap: () {
                _contentController.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: _contentController.text.length,
                );
              },
              onChanged: (value) => setState(() => alarmContent = value),
            ),
            const SizedBox(height: 16),

            GestureDetector(
              onTap: () async {
                final time = await CircularTimePicker.show(
                  context,
                  initialTime: selectedTime ?? TimeOfDay.now(),
                );
                if (time != null) setState(() => selectedTime = time);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: selectedTime != null
                      ? Theme.of(context).colorScheme.primary.withOpacity(0.08)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selectedTime != null
                        ? Theme.of(context).colorScheme.primary.withOpacity(0.5)
                        : Theme.of(context).colorScheme.outline,
                    width: selectedTime != null ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 20,
                      color: selectedTime != null
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      selectedTime == null
                          ? 'Select time'
                          : '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: selectedTime != null
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: selectedTime != null
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    if (selectedTime != null)
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.6),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            Text('Repeat', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            DropdownButtonFormField<RepeatType>(
              value: selectedRepeatType,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              items: RepeatType.values.map((type) {
                String label;
                switch (type) {
                  case RepeatType.once:
                    label = 'Once';
                    break;
                  case RepeatType.daily:
                    label = 'Every day';
                    break;
                  case RepeatType.weekdays:
                    label = 'Weekdays (Mon–Fri)';
                    break;
                  case RepeatType.weekends:
                    label = 'Weekends (Sat–Sun)';
                    break;
                  case RepeatType.custom:
                    label = 'Custom';
                    break;
                }
                return DropdownMenuItem(value: type, child: Text(label));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedRepeatType = value!;
                  if (value != RepeatType.custom) {
                    selectedDays.clear();
                  }
                });
              },
            ),

            if (selectedRepeatType == RepeatType.custom) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: List.generate(7, (index) {
                  final isSelected = selectedDays.contains(index);
                  return FilterChip(
                    label: Text(dayNames[index]),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          selectedDays.add(index);
                        } else {
                          selectedDays.remove(index);
                        }
                      });
                    },
                  );
                }),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            if (alarmContent.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter a label')),
              );
              return;
            }
            if (selectedTime == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please select a time')),
              );
              return;
            }
            if (selectedRepeatType == RepeatType.custom &&
                selectedDays.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please select at least one day')),
              );
              return;
            }

            try {
              final now = DateTime.now();
              final scheduledTime = DateTime(
                now.year,
                now.month,
                now.day,
                selectedTime!.hour,
                selectedTime!.minute,
              );

              await _alarmService.addAlarmWithRepeat(
                content: alarmContent,
                scheduledTime: scheduledTime,
                repeatType: selectedRepeatType,
                customDays: selectedRepeatType == RepeatType.custom
                    ? selectedDays.toList()
                    : null,
                mode: selectedMode,
              );

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Alarm set for ${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}',
                    ),
                    backgroundColor: theme.colorScheme.primary,
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to set alarm: $e'),
                    backgroundColor: theme.colorScheme.error,
                  ),
                );
              }
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

// ── Mode selector widget ───────────────────────────────────────────────────────

class _ModeSelector extends StatelessWidget {
  final AlarmMode selected;
  final ValueChanged<AlarmMode> onChanged;

  const _ModeSelector({required this.selected, required this.onChanged});

  static const _modes = [
    (
      mode: AlarmMode.chaos,
      icon: Icons.bolt,
      label: 'Chaos',
      desc: 'Pop targets',
      color: Color(0xFFCC2233),
    ),
    (
      mode: AlarmMode.mood,
      icon: Icons.auto_awesome,
      label: 'Mood',
      desc: 'Swipe up',
      color: Color(0xFF7C3AED),
    ),
    (
      mode: AlarmMode.ghost,
      icon: Icons.nightlight_round,
      label: 'Ghost',
      desc: 'Silent',
      color: Color(0xFF546E7A),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _modes.map((m) {
        final isSelected = selected == m.mode;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onChanged(m.mode);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? m.color.withOpacity(0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? m.color : m.color.withOpacity(0.25),
                  width: isSelected ? 1.5 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: m.color.withOpacity(0.38),
                          blurRadius: 14,
                          spreadRadius: 0,
                        ),
                      ]
                    : [],
              ),
              child: Column(
                children: [
                  Icon(
                    m.icon,
                    color: isSelected ? m.color : m.color.withOpacity(0.5),
                    size: 22,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    m.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected ? m.color : m.color.withOpacity(0.6),
                    ),
                  ),
                  Text(
                    m.desc,
                    style: TextStyle(
                      fontSize: 9,
                      color: isSelected
                          ? m.color.withOpacity(0.7)
                          : m.color.withOpacity(0.35),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
