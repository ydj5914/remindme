import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/alarm_item.dart';
import '../services/alarm_service.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alarmService = AlarmService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'clear') {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Clear History'),
                    content: const Text('Delete all history entries?'),
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
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true && context.mounted) {
                  await alarmService.clearHistory();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('History cleared')),
                  );
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep),
                    SizedBox(width: 8),
                    Text('Clear All'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<List<AlarmItem>>(
        stream: alarmService.getHistoryStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final history = snapshot.data ?? [];

          if (history.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history,
                    size: 64,
                    color: theme.colorScheme.onSurface.withOpacity(0.2),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No completed alarms yet',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            itemCount: history.length,
            itemBuilder: (context, index) {
              final isLast = index == history.length - 1;
              return _TimelineItem(
                alarm: history[index],
                isLast: isLast,
                onDelete: () => alarmService.deleteHistory(history[index]),
                onNoteChanged: (note) =>
                    alarmService.updateHistoryNote(history[index].id, note),
              );
            },
          );
        },
      ),
    );
  }
}

class _TimelineItem extends StatefulWidget {
  final AlarmItem alarm;
  final bool isLast;
  final VoidCallback onDelete;
  final Future<void> Function(String) onNoteChanged;

  const _TimelineItem({
    required this.alarm,
    required this.isLast,
    required this.onDelete,
    required this.onNoteChanged,
  });

  @override
  State<_TimelineItem> createState() => _TimelineItemState();
}

class _TimelineItemState extends State<_TimelineItem> {
  void _showNoteDialog() async {
    String note = widget.alarm.note ?? '';
    final controller = TextEditingController(text: note);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add a note',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              widget.alarm.content,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 16),
            // Quick emoji row
            Wrap(
              spacing: 8,
              children: ['🎯', '✅', '💪', '🌟', '😴', '🏃', '💧', '📖']
                  .map(
                    (e) => GestureDetector(
                      onTap: () {
                        controller.text = e;
                        note = e;
                      },
                      child: Text(e, style: const TextStyle(fontSize: 28)),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              onChanged: (v) => note = v,
              decoration: const InputDecoration(
                hintText: 'How did it go?',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await widget.onNoteChanged(controller.text);
                },
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeFormat = DateFormat('HH:mm');
    final dateFormat = DateFormat('MMM d');
    final categoryColor = widget.alarm.categoryColor;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline line + dot
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: categoryColor,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!widget.isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: theme.colorScheme.onSurface.withOpacity(0.1),
                    ),
                  ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: 12,
                bottom: widget.isLast ? 0 : 20,
              ),
              child: Dismissible(
                key: Key(widget.alarm.id),
                direction: DismissDirection.endToStart,
                onDismissed: (_) => widget.onDelete(),
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.delete, color: theme.colorScheme.onError),
                ),
                child: GestureDetector(
                  onTap: _showNoteDialog,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border:
                          widget.alarm.note != null &&
                              widget.alarm.note!.isNotEmpty
                          ? Border.all(color: categoryColor.withOpacity(0.4))
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              widget.alarm.categoryIcon,
                              size: 14,
                              color: categoryColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              widget.alarm.content,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              timeFormat.format(widget.alarm.time),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: categoryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        if (widget.alarm.completedAt != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Completed ${dateFormat.format(widget.alarm.completedAt!)} at ${timeFormat.format(widget.alarm.completedAt!)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.4,
                              ),
                            ),
                          ),
                        ],
                        if (widget.alarm.note != null &&
                            widget.alarm.note!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: categoryColor.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              widget.alarm.note!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: categoryColor,
                              ),
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 6),
                          Text(
                            'Tap to add note ✏️',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.25,
                              ),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
