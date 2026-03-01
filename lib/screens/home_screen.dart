import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RemindMeHomeScreen extends StatefulWidget {
  const RemindMeHomeScreen({super.key});

  @override
  State<RemindMeHomeScreen> createState() => _RemindMeHomeScreenState();
}

class _RemindMeHomeScreenState extends State<RemindMeHomeScreen> {
  // 실제 개발 시에는 Firestore에서 가져올 데이터입니다.
  final List<AlarmItem> _alarmList = [
    AlarmItem(
      id: '1',
      time: DateTime.now().add(const Duration(hours: 1)),
      content: '영양제 먹기',
      isActive: true,
    ),
    AlarmItem(
      id: '2',
      time: DateTime.now().add(const Duration(hours: 3)),
      content: '팀 미팅 준비',
      isActive: true,
    ),
  ];

  void _showAddAlarmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('새 알람 추가'),
        content: const Text('알람 추가 기능은 곧 구현됩니다!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddAlarmDialog,
        backgroundColor: colorScheme.primary,
        child: Icon(Icons.add, color: colorScheme.onPrimary),
      ),
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Remind Me',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 인사말 섹션
            Text(
              '안녕하세요!',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '오늘 설정된 알람이 ${_alarmList.length}개 있습니다.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24),

            // 2. 알람 리스트 섹션
            Text(
              '내 알람 목록',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            // 3. 알람 리스트 또는 빈 상태
            Expanded(
              child: _alarmList.isEmpty
                  ? Center(
                      child: Text(
                        '설정된 알람이 없어요.\n+ 버튼을 눌러보세요!',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _alarmList.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        return AlarmItemCard(
                          alarm: _alarmList[index],
                          onToggle: (value) {
                            setState(() {
                              _alarmList[index].isActive = value;
                            });
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class AlarmItem {
  final String id;
  final DateTime time;
  final String content;
  bool isActive;

  AlarmItem({
    required this.id,
    required this.time,
    required this.content,
    required this.isActive,
  });
}

class AlarmItemCard extends StatelessWidget {
  final AlarmItem alarm;
  final ValueChanged<bool> onToggle;

  const AlarmItemCard({
    super.key,
    required this.alarm,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeFormat = DateFormat('HH:mm');

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(
              Icons.notifications,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    timeFormat.format(alarm.time),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    alarm.content,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Switch(
              value: alarm.isActive,
              onChanged: onToggle,
            ),
          ],
        ),
      ),
    );
  }
}
