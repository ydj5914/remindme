import 'package:flutter/material.dart';
import '../models/alarm_item.dart';
import '../services/alarm_service.dart';
import 'custom_time_picker.dart';

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
  Set<int> selectedDays = {};

  final List<String> dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  late TextEditingController _contentController;

  @override
  void initState() {
    super.initState();
    alarmContent = widget.prefillContent ?? '';
    _contentController = TextEditingController(text: alarmContent);
  }

  @override
  void dispose() {
    _contentController.dispose();
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
            TextField(
              controller: _contentController,
              decoration: const InputDecoration(
                labelText: 'Label',
                hintText: 'e.g. Take vitamins',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  alarmContent = value;
                });
              },
            ),
            const SizedBox(height: 16),

            OutlinedButton.icon(
              onPressed: () async {
                final time = await CustomTimePicker.show(
                  context,
                  initialTime: selectedTime ?? TimeOfDay.now(),
                );
                if (time != null) {
                  setState(() => selectedTime = time);
                }
              },
              icon: const Icon(Icons.access_time),
              label: Text(
                selectedTime == null
                    ? 'Select time'
                    : '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}',
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
            if (selectedRepeatType == RepeatType.custom && selectedDays.isEmpty) {
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
