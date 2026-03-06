import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import '../models/alarm_item.dart';
import 'alarm_service.dart';

class WidgetService {
  static final WidgetService _instance = WidgetService._internal();
  factory WidgetService() => _instance;
  WidgetService._internal();

  final AlarmService _alarmService = AlarmService();

  // ── Update widget data ────────────────────────────────────────────────────

  Future<void> updateWidget() async {
    try {
      final alarms = await _alarmService.getActiveAlarms();
      alarms.sort((a, b) => a.time.compareTo(b.time));

      if (alarms.isEmpty) {
        await HomeWidget.saveWidgetData<String>('alarm_time', 'No alarms');
        await HomeWidget.saveWidgetData<String>(
          'alarm_content',
          'Tap to add one',
        );
        await HomeWidget.saveWidgetData<String>('alarm_count', '0');
        await HomeWidget.saveWidgetData<String>('ghost_alarm_id', '');
      } else {
        final next = alarms.first;
        final fmt = DateFormat('HH:mm');

        await HomeWidget.saveWidgetData<String>(
          'alarm_time',
          fmt.format(next.time),
        );
        await HomeWidget.saveWidgetData<String>('alarm_content', next.content);
        await HomeWidget.saveWidgetData<String>('alarm_id', next.id);
        await HomeWidget.saveWidgetData<String>(
          'alarm_count',
          '${alarms.length}',
        );
        await HomeWidget.saveWidgetData<String>('alarm_mode', next.modeLabel);

        // Ghost quick-complete: expose the first Ghost alarm's ID
        final ghostAlarm = alarms.cast<AlarmItem?>().firstWhere(
          (a) => a?.mode == AlarmMode.ghost,
          orElse: () => null,
        );
        await HomeWidget.saveWidgetData<String>(
          'ghost_alarm_id',
          ghostAlarm?.id ?? '',
        );
        if (ghostAlarm != null) {
          await HomeWidget.saveWidgetData<String>(
            'ghost_alarm_content',
            ghostAlarm.content,
          );
        }
      }

      await HomeWidget.updateWidget(
        androidName: 'RemindMeWidgetProvider',
        iOSName: 'RemindMeWidget',
      );
    } catch (_) {}
  }

  // ── Initialize + listen for widget taps ───────────────────────────────────

  Future<void> initializeWidget() async {
    try {
      HomeWidget.widgetClicked.listen((Uri? uri) {
        if (uri == null) return;
        final action = uri.queryParameters['action'];
        final alarmId = uri.queryParameters['alarmId'];
        if (action == 'complete' && alarmId != null) {
          _completeFromWidget(alarmId);
        }
      });
      await updateWidget();
    } catch (_) {}
  }

  Future<void> _completeFromWidget(String alarmId) async {
    try {
      await _alarmService.completeAlarm(alarmId);
      await updateWidget();
    } catch (_) {}
  }
}
