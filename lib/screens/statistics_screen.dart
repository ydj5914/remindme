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
      appBar: AppBar(title: const Text('Stats')),
      body: StreamBuilder<List<AlarmItem>>(
        stream: alarmService.getHistoryStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final history = snapshot.data ?? [];
          final stats = _calculateStats(history);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Analysis phrase
                if (history.isNotEmpty) ...[
                  _AnalysisBanner(
                    weekCount: stats['thisWeek'] as int,
                    weekTotal: stats['weekTotal'] as int,
                    theme: theme,
                  ),
                  const SizedBox(height: 20),
                ],

                // Summary cards
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'Total Done',
                        value: '${history.length}',
                        icon: Icons.done_all,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        title: 'This Week',
                        value: '${stats['thisWeek']}',
                        icon: Icons.calendar_today,
                        color: const Color(0xFF26A69A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'Avg Snooze',
                        value: '${stats['avgSnooze']}x',
                        icon: Icons.snooze,
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        title: 'Best Day',
                        value: stats['bestDay'] as String,
                        icon: Icons.emoji_events_outlined,
                        color: const Color(0xFFFFA726),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // 30-day Heatmap
                Text('30-Day Activity', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  'Color intensity = completions per day',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.4),
                  ),
                ),
                const SizedBox(height: 16),
                _HeatmapGrid(history: history, baseColor: theme.colorScheme.primary),

                const SizedBox(height: 32),

                // Category breakdown
                Text('By Category', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                if (history.isEmpty)
                  Center(
                    child: Text('No data yet',
                        style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.3))),
                  )
                else
                  SizedBox(
                    height: 180,
                    child: _CategoryPieChart(history: history),
                  ),

                const SizedBox(height: 32),

                // Weekly bar chart
                Text('Weekly Trend', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                SizedBox(height: 180, child: _WeeklyBarChart(history: history)),
              ],
            ),
          );
        },
      ),
    );
  }

  Map<String, dynamic> _calculateStats(List<AlarmItem> history) {
    if (history.isEmpty) {
      return {
        'thisWeek': 0,
        'weekTotal': 7,
        'avgSnooze': '0.0',
        'bestDay': '-',
      };
    }

    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final thisWeek = history
        .where((a) => a.completedAt != null && a.completedAt!.isAfter(weekAgo))
        .length;

    final totalSnooze =
        history.fold<int>(0, (sum, a) => sum + a.snoozeCount);
    final avgSnooze = (totalSnooze / history.length).toStringAsFixed(1);

    // Best weekday
    final counts = List.filled(7, 0);
    for (final a in history) {
      if (a.completedAt != null) {
        counts[a.completedAt!.weekday - 1]++;
      }
    }
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final maxIdx = counts.indexOf(counts.reduce((a, b) => a > b ? a : b));
    final bestDay = counts[maxIdx] > 0 ? days[maxIdx] : '-';

    return {
      'thisWeek': thisWeek,
      'weekTotal': 7,
      'avgSnooze': avgSnooze,
      'bestDay': bestDay,
    };
  }
}

class _AnalysisBanner extends StatelessWidget {
  final int weekCount;
  final int weekTotal;
  final ThemeData theme;

  const _AnalysisBanner({
    required this.weekCount,
    required this.weekTotal,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final pct = weekTotal > 0 ? (weekCount / weekTotal * 100).round() : 0;
    final emoji = pct >= 80 ? '🚀' : pct >= 50 ? '💪' : '🌱';
    final msg = pct >= 80
        ? "You're crushing it!"
        : pct >= 50
            ? "Keep the momentum going!"
            : "Every streak starts with one.";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withOpacity(0.2),
            theme.colorScheme.secondary.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$emoji $msg',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "You've completed $weekCount routine${weekCount == 1 ? '' : 's'} this week.",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeatmapGrid extends StatelessWidget {
  final List<AlarmItem> history;
  final Color baseColor;

  const _HeatmapGrid({required this.history, required this.baseColor});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = List.generate(30, (i) {
      final d = now.subtract(Duration(days: 29 - i));
      return DateTime(d.year, d.month, d.day);
    });

    // Count completions per day
    final counts = <DateTime, int>{};
    for (final a in history) {
      if (a.completedAt != null) {
        final d = DateTime(
          a.completedAt!.year,
          a.completedAt!.month,
          a.completedAt!.day,
        );
        counts[d] = (counts[d] ?? 0) + 1;
      }
    }
    final maxCount = counts.values.fold(0, (a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Day labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(DateFormat('MMM d').format(days.first),
                style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.4))),
            Text(DateFormat('MMM d').format(days.last),
                style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.4))),
          ],
        ),
        const SizedBox(height: 8),
        // Grid
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: days.map((day) {
            final count = counts[day] ?? 0;
            final intensity = maxCount > 0 ? count / maxCount : 0.0;
            return Tooltip(
              message:
                  '${DateFormat('MMM d').format(day)}: $count completion${count == 1 ? '' : 's'}',
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: count == 0
                      ? Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.07)
                      : baseColor.withOpacity(0.2 + intensity * 0.8),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        // Legend
        Row(
          children: [
            Text('Less  ',
                style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.4))),
            ...List.generate(
              5,
              (i) => Container(
                width: 14,
                height: 14,
                margin: const EdgeInsets.only(right: 3),
                decoration: BoxDecoration(
                  color: i == 0
                      ? Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.07)
                      : baseColor.withOpacity(0.2 + (i / 4) * 0.8),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            Text('  More',
                style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.4))),
          ],
        ),
      ],
    );
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
            Icon(icon, color: color, size: 28),
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
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.55),
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
    for (final a in history) {
      categoryCount[a.category] = (categoryCount[a.category] ?? 0) + 1;
    }
    if (categoryCount.isEmpty) {
      return const Center(child: Text('No data'));
    }
    return PieChart(
      PieChartData(
        sections: categoryCount.entries.map((entry) {
          final pct = (entry.value / history.length * 100).toInt();
          return PieChartSectionData(
            value: entry.value.toDouble(),
            title: '$pct%',
            color: AlarmItem(
              id: '',
              time: DateTime.now(),
              content: '',
              isActive: false,
              category: entry.key,
            ).categoryColor,
            radius: 50,
            titleStyle: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
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
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final counts = List.filled(7, 0);
    for (final a in history) {
      if (a.completedAt != null) {
        counts[a.completedAt!.weekday - 1]++;
      }
    }
    final maxY = counts.reduce((a, b) => a > b ? a : b).toDouble();

    return BarChart(
      BarChartData(
        maxY: maxY + 1,
        barGroups: List.generate(7, (i) {
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: counts[i].toDouble(),
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.secondary,
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
                width: 18,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }),
        titlesData: FlTitlesData(
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) => Text(
                weekdays[value.toInt()],
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.5),
                ),
              ),
            ),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
      ),
    );
  }
}
