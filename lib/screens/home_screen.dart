import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/notification_service.dart';

class RemindMeHomeScreen extends StatefulWidget {
  const RemindMeHomeScreen({super.key});

  @override
  State<RemindMeHomeScreen> createState() => _RemindMeHomeScreenState();
}

class _RemindMeHomeScreenState extends State<RemindMeHomeScreen> {
  final NotificationService _notificationService = NotificationService();
  final List<AlarmItem> _alarmList = [];

  @override
  void initState() {
    super.initState();
    _loadPendingAlarms();
  }

  Future<void> _loadPendingAlarms() async {
    // 예약된 알람 목록 불러오기
    final pending = await _notificationService.getPendingAlarms();
    setState(() {
      _alarmList.clear();
      for (var alarm in pending) {
        _alarmList.add(AlarmItem(
          id: alarm.id.toString(),
          time: DateTime.now(), // 실제로는 payload에서 파싱 필요
          content: alarm.body ?? '알람',
          isActive: true,
        ));
      }
    });
  }

  Future<void> _showAddAlarmDialog() async {
    String alarmContent = '';
    TimeOfDay? selectedTime;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('새 알람 추가'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: '알람 내용',
                  hintText: '예: 영양제 먹기',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  alarmContent = value;
                },
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          timePickerTheme: TimePickerThemeData(
                            backgroundColor:
                                Theme.of(context).colorScheme.surface,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (time != null) {
                    setDialogState(() {
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
            ],
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

                try {
                  // 알람 등록
                  final now = DateTime.now();
                  final scheduledTime = DateTime(
                    now.year,
                    now.month,
                    now.day,
                    selectedTime!.hour,
                    selectedTime!.minute,
                  );

                  final alarmId = scheduledTime.millisecondsSinceEpoch ~/ 1000;

                  await _notificationService.scheduleAlarm(
                    id: alarmId,
                    title: 'Remind Me',
                    content: alarmContent,
                    scheduledTime: scheduledTime,
                  );

                  // 리스트에 추가
                  setState(() {
                    _alarmList.add(AlarmItem(
                      id: alarmId.toString(),
                      time: scheduledTime,
                      content: alarmContent,
                      isActive: true,
                    ));
                  });

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '알람이 ${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}에 설정되었습니다',
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('알람 설정 실패: $e')),
                    );
                  }
                }
              },
              child: const Text('추가'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteAlarm(AlarmItem alarm) async {
    await _notificationService.cancelAlarm(int.parse(alarm.id));
    setState(() {
      _alarmList.remove(alarm);
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('알람이 삭제되었습니다')),
      );
    }
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
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.alarm_off,
                            size: 64,
                            color: theme.colorScheme.onSurface.withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '설정된 알람이 없어요.\n+ 버튼을 눌러보세요!',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color:
                                  theme.colorScheme.onSurface.withOpacity(0.5),
                            ),
                          ),
                        ],
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
                            if (!value) {
                              _notificationService
                                  .cancelAlarm(int.parse(_alarmList[index].id));
                            }
                          },
                          onDelete: () => _deleteAlarm(_alarmList[index]),
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
  final VoidCallback onDelete;

  const AlarmItemCard({
    super.key,
    required this.alarm,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeFormat = DateFormat('HH:mm');

    return Dismissible(
      key: Key(alarm.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: theme.colorScheme.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.delete,
          color: theme.colorScheme.onError,
        ),
      ),
      child: Card(
        elevation: 0,
        color: theme.colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(
                Icons.notifications,
                color: alarm.isActive
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withOpacity(0.3),
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
                        color: alarm.isActive
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      alarm.content,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: alarm.isActive
                            ? null
                            : theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
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
      ),
    );
  }
}
