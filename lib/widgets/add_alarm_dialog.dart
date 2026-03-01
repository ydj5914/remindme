import 'package:flutter/material.dart';
import '../models/alarm_item.dart';
import '../services/alarm_service.dart';

class AddAlarmDialog extends StatefulWidget {
  const AddAlarmDialog({super.key});

  @override
  State<AddAlarmDialog> createState() => _AddAlarmDialogState();
}

class _AddAlarmDialogState extends State<AddAlarmDialog> {
  final AlarmService _alarmService = AlarmService();
  String alarmContent = '';
  TimeOfDay? selectedTime;
  RepeatType selectedRepeatType = RepeatType.daily;
  Set<int> selectedDays = {};

  final List<String> dayNames = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('새 알람 추가'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 알람 내용 입력
            TextField(
              decoration: const InputDecoration(
                labelText: '알람 내용',
                hintText: '예: 영양제 먹기',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  alarmContent = value;
                });
              },
            ),
            const SizedBox(height: 16),

            // 시간 선택
            OutlinedButton.icon(
              onPressed: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                  builder: (context, child) {
                    return Theme(
                      data: theme.copyWith(
                        timePickerTheme: TimePickerThemeData(
                          backgroundColor: theme.colorScheme.surface,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (time != null) {
                  setState(() {
                    selectedTime = time;
                  });
                }
              },
              icon: const Icon(Icons.access_time),
              label: Text(
                selectedTime == null
                    ? '시간 선택'
                    : '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}',
              ),
            ),
            const SizedBox(height: 16),

            // 반복 설정
            Text(
              '반복 설정',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<RepeatType>(
              value: selectedRepeatType,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: RepeatType.values.map((type) {
                String label;
                switch (type) {
                  case RepeatType.once:
                    label = '한 번만';
                    break;
                  case RepeatType.daily:
                    label = '매일';
                    break;
                  case RepeatType.weekdays:
                    label = '주중 (월-금)';
                    break;
                  case RepeatType.weekends:
                    label = '주말 (토-일)';
                    break;
                  case RepeatType.custom:
                    label = '사용자 지정';
                    break;
                }
                return DropdownMenuItem(
                  value: type,
                  child: Text(label),
                );
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

            // 사용자 지정 요일 선택
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
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () async {
            if (alarmContent.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('알람 내용을 입력해주세요')),
              );
              return;
            }
            if (selectedTime == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('시간을 선택해주세요')),
              );
              return;
            }
            if (selectedRepeatType == RepeatType.custom &&
                selectedDays.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('요일을 선택해주세요')),
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
                      '알람이 ${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}에 설정되었습니다',
                    ),
                    backgroundColor: theme.colorScheme.primary,
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('알람 설정 실패: $e'),
                    backgroundColor: theme.colorScheme.error,
                  ),
                );
              }
            }
          },
          child: const Text('추가'),
        ),
      ],
    );
  }
}
