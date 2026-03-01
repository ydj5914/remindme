import 'package:home_widget/home_widget.dart';
import '../models/alarm_item.dart';
import 'alarm_service.dart';
import 'package:intl/intl.dart';

class WidgetService {
  static final WidgetService _instance = WidgetService._internal();
  factory WidgetService() => _instance;
  WidgetService._internal();

  final AlarmService _alarmService = AlarmService();

  /// 위젯 업데이트
  Future<void> updateWidget() async {
    try {
      // 다음 알람 가져오기
      final alarms = await _alarmService.getActiveAlarms();

      if (alarms.isEmpty) {
        await HomeWidget.saveWidgetData<String>('alarm_time', '알람 없음');
        await HomeWidget.saveWidgetData<String>('alarm_content', '새 알람을 추가하세요');
      } else {
        // 가장 빠른 알람 찾기
        alarms.sort((a, b) => a.time.compareTo(b.time));
        final nextAlarm = alarms.first;

        final timeFormat = DateFormat('HH:mm');
        await HomeWidget.saveWidgetData<String>(
          'alarm_time',
          timeFormat.format(nextAlarm.time),
        );
        await HomeWidget.saveWidgetData<String>(
          'alarm_content',
          nextAlarm.content,
        );
        await HomeWidget.saveWidgetData<String>('alarm_id', nextAlarm.id);
        await HomeWidget.saveWidgetData<String>(
          'category',
          nextAlarm.categoryLabel,
        );
      }

      // 위젯 갱신
      await HomeWidget.updateWidget(
        androidName: 'RemindMeWidgetProvider',
        iOSName: 'RemindMeWidget',
      );

      print('위젯 업데이트 완료');
    } catch (e) {
      print('위젯 업데이트 실패: $e');
    }
  }

  /// 위젯 초기화
  Future<void> initializeWidget() async {
    try {
      // 위젯 클릭 리스너
      HomeWidget.widgetClicked.listen((Uri? uri) {
        if (uri != null) {
          final action = uri.queryParameters['action'];
          final alarmId = uri.queryParameters['alarmId'];

          if (action == 'complete' && alarmId != null) {
            _completeAlarmFromWidget(alarmId);
          }
        }
      });

      // 초기 업데이트
      await updateWidget();
    } catch (e) {
      print('위젯 초기화 실패: $e');
    }
  }

  /// 위젯에서 알람 완료
  Future<void> _completeAlarmFromWidget(String alarmId) async {
    try {
      await _alarmService.completeAlarm(alarmId);
      await updateWidget();
    } catch (e) {
      print('위젯에서 알람 완료 실패: $e');
    }
  }
}
