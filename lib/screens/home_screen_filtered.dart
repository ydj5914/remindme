import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/alarm_item.dart';
import '../services/alarm_service.dart';
import '../widgets/add_alarm_dialog.dart';
import '../widgets/category_filter.dart';
import '../services/widget_service.dart';

class RemindMeHomeScreenFiltered extends StatefulWidget {
  const RemindMeHomeScreenFiltered({super.key});

  @override
  State<RemindMeHomeScreenFiltered> createState() =>
      _RemindMeHomeScreenFilteredState();
}

class _RemindMeHomeScreenFilteredState
    extends State<RemindMeHomeScreenFiltered> {
  final AlarmService _alarmService = AlarmService();
  AlarmCategory? _selectedCategory;

  Future<void> _showAddAlarmDialog() async {
    await showDialog(
      context: context,
      builder: (context) => const AddAlarmDialog(),
    );
    // 위젯 업데이트
    WidgetService().updateWidget();
  }

  Future<void> _deleteAlarm(AlarmItem alarm) async {
    try {
      await _alarmService.deleteAlarm(alarm);
      WidgetService().updateWidget();
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
      WidgetService().updateWidget();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('알람 토글 실패: $e')));
      }
    }
  }

  List<AlarmItem> _filterAlarms(List<AlarmItem> alarms) {
    if (_selectedCategory == null) {
      return alarms;
    }
    return alarms
        .where((alarm) => alarm.category == _selectedCategory)
        .toList();
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
            tooltip: '알람 동기화',
            onPressed: () async {
              await _alarmService.syncAlarms();
              WidgetService().updateWidget();
              if (mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('알람이 동기화되었습니다')));
              }
            },
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

          final allAlarms = snapshot.data ?? [];
          final filteredAlarms = _filterAlarms(allAlarms);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 카테고리 필터
              CategoryFilter(
                selectedCategory: _selectedCategory,
                onCategoryChanged: (category) {
                  setState(() {
                    _selectedCategory = category;
                  });
                },
              ),

              // 헤더
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '안녕하세요!',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _selectedCategory == null
                          ? '오늘 설정된 알람이 ${filteredAlarms.length}개 있습니다.'
                          : '${AlarmItem(id: '', time: DateTime.now(), content: '', isActive: false, category: _selectedCategory!).categoryLabel} 알람이 ${filteredAlarms.length}개 있습니다.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '내 알람 목록',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (filteredAlarms.isNotEmpty)
                          Text(
                            '← 스와이프로 삭제',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.5,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // 알람 리스트
              Expanded(
                child: filteredAlarms.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.alarm_off,
                              size: 64,
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.3,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _selectedCategory == null
                                  ? '설정된 알람이 없어요.\n+ 버튼을 눌러보세요!'
                                  : '이 카테고리에 알람이 없어요.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filteredAlarms.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          return AlarmItemCard(
                            alarm: filteredAlarms[index],
                            onToggle: (value) =>
                                _toggleAlarm(filteredAlarms[index]),
                            onDelete: () => _deleteAlarm(filteredAlarms[index]),
                          );
                        },
                      ),
              ),
            ],
          );
        },
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

    return Dismissible(
      key: Key(alarm.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('알람 삭제'),
            content: Text('\'${alarm.content}\' 알람을 삭제하시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                ),
                child: const Text('삭제'),
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
        color: alarm.categoryColor.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: alarm.categoryColor.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 50,
                decoration: BoxDecoration(
                  color: alarm.categoryColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.notifications,
                color: alarm.isActive
                    ? alarm.categoryColor
                    : theme.colorScheme.onSurface.withOpacity(0.3),
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
                            ? alarm.categoryColor
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
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          alarm.repeatLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.4),
                          ),
                        ),
                        const Text(' • '),
                        Text(
                          alarm.categoryLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: alarm.categoryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Switch(
                value: alarm.isActive,
                onChanged: (_) => onToggle(),
                activeColor: alarm.categoryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
