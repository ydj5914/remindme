import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/alarm_item.dart';
import '../services/alarm_service.dart';
import '../widgets/add_alarm_dialog.dart';
import 'login_screen.dart';

class RemindMeHomeScreen extends StatefulWidget {
  const RemindMeHomeScreen({super.key});

  @override
  State<RemindMeHomeScreen> createState() => _RemindMeHomeScreenState();
}

class _RemindMeHomeScreenState extends State<RemindMeHomeScreen> {
  final AlarmService _alarmService = AlarmService();

  Future<void> _showAddAlarmDialog({String? prefillContent}) async {
    final user = FirebaseAuth.instance.currentUser;
    final isGuest = user?.isAnonymous ?? true;
    if (isGuest) {
      final count = await _alarmService.getAlarmCount();
      if (count >= 5) {
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Upgrade to Continue'),
            content: const Text(
              'You\'ve used all 5 free alarm slots.\nSign in to unlock unlimited alarms and sync across devices.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Later'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()));
                },
                child: const Text('Sign In'),
              ),
            ],
          ),
        );
        return;
      }
    }
    await showDialog(
      context: context,
      builder: (context) => AddAlarmDialog(prefillContent: prefillContent),
    );
  }

  Future<void> _showOldAddAlarmDialog() async {
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
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.surface,
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
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('시간을 선택해주세요')));
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

                  // AlarmService를 통해 Firestore + 로컬 알람 동시 등록
                  await _alarmService.addAlarm(
                    content: alarmContent,
                    scheduledTime: scheduledTime,
                  );

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '알람이 ${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}에 설정되었습니다',
                        ),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('알람 설정 실패: $e'),
                        backgroundColor: Theme.of(context).colorScheme.error,
                      ),
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
    try {
      await _alarmService.deleteAlarm(alarm);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('알람이 삭제되었습니다')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('알람 삭제 실패: $e')));
      }
    }
  }

  Future<void> _toggleAlarm(AlarmItem alarm) async {
    try {
      await _alarmService.toggleAlarm(alarm);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('알람 토글 실패: $e')));
      }
    }
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    return 'evening';
  }

  void _showAccountDialog() {
    final user = FirebaseAuth.instance.currentUser;
    final isGuest = user?.isAnonymous ?? true;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isGuest)
              const Text('Guest mode', style: TextStyle(fontSize: 14))
            else ...[
              if (user?.displayName != null)
                Text(user!.displayName!, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              if (user?.email != null)
                Text(user!.email!, style: const TextStyle(fontSize: 13)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          if (!isGuest)
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await GoogleSignIn().signOut();
                await FirebaseAuth.instance.signOut();
                // Re-sign in anonymously for guest mode
                await FirebaseAuth.instance.signInAnonymously();
              },
              child: const Text('Sign Out'),
            ),
          if (!isGuest)
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Account'),
                    content: const Text(
                      'This will permanently delete your account and all data. This action cannot be undone.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text(
                          'Delete',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  try {
                    await GoogleSignIn().signOut();
                    await FirebaseAuth.instance.currentUser?.delete();
                    await FirebaseAuth.instance.signInAnonymously();
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to delete account: $e')),
                      );
                    }
                  }
                }
              },
              child: const Text('Delete Account', style: TextStyle(color: Colors.red)),
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
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sync alarms',
            onPressed: () async {
              await _alarmService.syncAlarms();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Alarms synced')),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_circle),
            tooltip: '계정',
            onPressed: () => _showAccountDialog(),
          ),
        ],
      ),
      body: StreamBuilder<List<AlarmItem>>(
        stream: _alarmService.getAlarmsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: colorScheme.error),
                  const SizedBox(height: 16),
                  Text('오류가 발생했습니다', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final alarmList = snapshot.data ?? [];

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Header
                Text(
                  'Good ${_greeting()}!',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  alarmList.isEmpty
                      ? 'No alarms set yet.'
                      : '${alarmList.length} alarm${alarmList.length == 1 ? '' : 's'} scheduled.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 24),

                // 2. List header
                if (alarmList.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'My Alarms',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Swipe to delete',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                // 3. List or empty state
                Expanded(
                  child: alarmList.isEmpty
                      ? _QuickStartSection(
                          onTap: (content) =>
                              _showAddAlarmDialog(prefillContent: content),
                        )
                      : ListView.separated(
                          itemCount: alarmList.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            return AlarmItemCard(
                              alarm: alarmList[index],
                              onToggle: () => _toggleAlarm(alarmList[index]),
                              onDelete: () => _deleteAlarm(alarmList[index]),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _QuickStartSection extends StatelessWidget {
  final void Function(String content) onTap;
  const _QuickStartSection({required this.onTap});

  static const _suggestions = [
    (icon: Icons.wb_sunny_outlined, label: 'Wake up', color: Color(0xFFFFA726)),
    (icon: Icons.self_improvement, label: 'Meditate', color: Color(0xFF7C3AED)),
    (icon: Icons.water_drop_outlined, label: 'Drink Water', color: Color(0xFF29B6F6)),
    (icon: Icons.fitness_center, label: 'Exercise', color: Color(0xFF26A69A)),
    (icon: Icons.menu_book_outlined, label: 'Read', color: Color(0xFFEC407A)),
    (icon: Icons.bedtime_outlined, label: 'Sleep', color: Color(0xFF5C6BC0)),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 24),
          Icon(
            Icons.alarm_add_outlined,
            size: 56,
            color: theme.colorScheme.onSurface.withOpacity(0.2),
          ),
          const SizedBox(height: 12),
          Text(
            'No alarms yet',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Quick start with a routine:',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.3),
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: _suggestions.map((s) {
              return InkWell(
                onTap: () => onTap(s.label),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: s.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: s.color.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(s.icon, size: 18, color: s.color),
                      const SizedBox(width: 8),
                      Text(
                        s.label,
                        style: TextStyle(
                          color: s.color,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class AlarmItemCard extends StatelessWidget {
  final AlarmItem alarm;
  final VoidCallback onToggle;
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
    final categoryColor = alarm.categoryColor;

    return Dismissible(
      key: Key(alarm.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Alarm'),
            content: Text('Delete "${alarm.content}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: theme.colorScheme.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.delete, color: theme.colorScheme.onError),
      ),
      child: Card(
        elevation: 0,
        color: theme.colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: categoryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(alarm.categoryIcon, color: categoryColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      timeFormat.format(alarm.time),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: alarm.isActive
                            ? categoryColor
                            : theme.colorScheme.onSurface.withOpacity(0.4),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      alarm.content,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: alarm.isActive
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurface.withOpacity(0.4),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: categoryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            alarm.categoryLabel,
                            style: TextStyle(
                              fontSize: 10,
                              color: categoryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          alarm.repeatLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.4),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Switch(value: alarm.isActive, onChanged: (_) => onToggle()),
            ],
          ),
        ),
      ),
    );
  }
}
