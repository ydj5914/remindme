import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/alarm_item.dart';
import '../services/alarm_service.dart';
import 'package:intl/intl.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alarmService = AlarmService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('통계'),
      ),
      body: StreamBuilder<List<AlarmItem>>(
        stream: alarmService.getHistoryStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final history = snapshot.data ?? [];
          final stats = _calculateStatistics(history);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 요약 카드
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: '완료율',
                        value: '${stats['completionRate']}%',
                        icon: Icons.check_circle,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        title: '평균 스누즈',
                        value: '${stats['avgSnooze']}회',
                        icon: Icons.snooze,
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: '총 완료',
                        value: '${history.length}개',
                        icon: Icons.done_all,
                        color: theme.colorScheme.tertiary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        title: '이번 주',
                        value: '${stats['thisWeek']}개',
                        icon: Icons.calendar_today,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // 카테고리별 통계
                Text(
                  '카테고리별 완료',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: _CategoryPieChart(history: history),
                ),

                const SizedBox(height: 32),

                // 주간 추세
                Text(
                  '주간 완료 추세',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: _WeeklyBarChart(history: history),
                ),

                const SizedBox(height: 32),

                // 시간대별 완료
                Text(
                  '시간대별 완료',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                ...List.generate(24, (hour) {
                  final count = history
                      .where((alarm) => alarm.time.hour == hour)
                      .length;
                  if (count == 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 60,
                          child: Text(
                            '${hour.toString().padLeft(2, '0')}:00',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        Expanded(
                          child: LinearProgressIndicator(
                            value: count / history.length,
                            minHeight: 20,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('$count'),
                      ],
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  Map<String, dynamic> _calculateStatistics(List<AlarmItem> history) {
    if (history.isEmpty) {
      return {
        'completionRate': 0,
        'avgSnooze': 0,
        'thisWeek': 0,
      };
    }

    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));

    final thisWeekCount = history
        .where((alarm) => alarm.completedAt != null && alarm.completedAt!.isAfter(weekAgo))
        .length;

    final totalSnooze = history.fold<int>(0, (sum, alarm) => sum + alarm.snoozeCount);
    final avgSnooze = (totalSnooze / history.length).toStringAsFixed(1);

    return {
      'completionRate': 100, // 완료된 것만 히스토리에 있으므로 100%
      'avgSnooze': avgSnooze,
      'thisWeek': thisWeekCount,
    };
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryPieChart extends StatelessWidget {
  final List<AlarmItem> history;

  const _CategoryPieChart({required this.history});

  @override
  Widget build(BuildContext context) {
    final categoryCount = <AlarmCategory, int>{};
    for (final alarm in history) {
      categoryCount[alarm.category] = (categoryCount[alarm.category] ?? 0) + 1;
    }

    if (categoryCount.isEmpty) {
      return const Center(child: Text('데이터가 없습니다'));
    }

    return PieChart(
      PieChartData(
        sections: categoryCount.entries.map((entry) {
          final percentage = (entry.value / history.length * 100).toInt();
          return PieChartSectionData(
            value: entry.value.toDouble(),
            title: '$percentage%',
            color: AlarmItem(
              id: '',
              time: DateTime.now(),
              content: '',
              isActive: false,
              category: entry.key,
            ).categoryColor,
            radius: 50,
          );
        }).toList(),
        sectionsSpace: 2,
        centerSpaceRadius: 40,
      ),
    );
  }
}

class _WeeklyBarChart extends StatelessWidget {
  final List<AlarmItem> history;

  const _WeeklyBarChart({required this.history});

  @override
  Widget build(BuildContext context) {
    final weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final counts = List.filled(7, 0);

    for (final alarm in history) {
      if (alarm.completedAt != null) {
        final weekday = alarm.completedAt!.weekday - 1;
        counts[weekday]++;
      }
    }

    return BarChart(
      BarChartData(
        maxY: counts.reduce((a, b) => a > b ? a : b).toDouble() + 1,
        barGroups: List.generate(7, (index) {
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: counts[index].toDouble(),
                color: Theme.of(context).colorScheme.primary,
                width: 20,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text(weekdays[value.toInt()]);
              },
            ),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
      ),
    );
  }
}
