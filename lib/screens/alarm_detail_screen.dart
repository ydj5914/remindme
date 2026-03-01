import 'package:flutter/material.dart';
import '../models/alarm_item.dart';
import '../services/alarm_service.dart';
import 'package:intl/intl.dart';

/// 알림 클릭 시 표시되는 알람 상세 화면 (선택적)
class AlarmDetailScreen extends StatelessWidget {
  final AlarmItem alarm;

  const AlarmDetailScreen({super.key, required this.alarm});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeFormat = DateFormat('HH:mm');

    return Scaffold(
      appBar: AppBar(title: const Text('알람 상세')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.alarm, size: 100, color: theme.colorScheme.primary),
            const SizedBox(height: 32),
            Text(
              timeFormat.format(alarm.time),
              style: theme.textTheme.displayLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              alarm.content,
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            FilledButton.icon(
              onPressed: () async {
                await AlarmService().completeAlarm(alarm.id);
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('알람이 완료되었습니다')));
                }
              },
              icon: const Icon(Icons.check),
              label: const Text('완료'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 16,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('닫기'),
            ),
          ],
        ),
      ),
    );
  }
}
