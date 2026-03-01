import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  // 알림 클릭 콜백 (외부에서 설정 가능)
  Function(String alarmId, String action)? onNotificationTapped;

  Future<void> initialize({
    Function(String alarmId, String action)? onNotificationTapped,
  }) async {
    this.onNotificationTapped = onNotificationTapped;

    // 타임존 초기화
    tz.initializeTimeZones();

    // Android 설정
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS 설정
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );

    // 알림 채널 생성 (Android 8.0 이상)
    await _createNotificationChannel();
  }

  void _handleNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    final actionId = response.actionId;

    if (payload != null && payload.isNotEmpty) {
      try {
        final data = jsonDecode(payload);
        final alarmId = data['alarmId'] as String;
        final action = actionId ?? 'open'; // 'open' 또는 'complete'

        print('Notification response: alarmId=$alarmId, action=$action');

        // 콜백 호출
        onNotificationTapped?.call(alarmId, action);
      } catch (e) {
        print('Failed to parse notification payload: $e');
      }
    }
  }

  Future<void> _createNotificationChannel() async {
    const androidChannel = AndroidNotificationChannel(
      'remindme_alarm_channel',
      '알람 알림',
      description: 'RemindMe 알람 알림을 위한 채널',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  Future<bool> requestPermissions() async {
    if (await Permission.notification.isDenied) {
      final status = await Permission.notification.request();
      return status.isGranted;
    }
    return true;
  }

  Future<void> scheduleAlarm({
    required int id,
    required String alarmId,
    required String title,
    required String content,
    required DateTime scheduledTime,
  }) async {
    // 권한 확인
    final hasPermission = await requestPermissions();
    if (!hasPermission) {
      throw Exception('알림 권한이 필요합니다');
    }

    // 현재 시간보다 이전이면 다음날로 설정
    DateTime targetTime = scheduledTime;
    if (scheduledTime.isBefore(DateTime.now())) {
      targetTime = scheduledTime.add(const Duration(days: 1));
    }

    final tzTime = tz.TZDateTime.from(targetTime, tz.local);

    // Payload에 알람 ID 포함
    final payload = jsonEncode({
      'alarmId': alarmId,
      'content': content,
    });

    // Android 알림 액션 버튼 정의
    const completeAction = AndroidNotificationAction(
      'complete',
      '완료',
      icon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      showsUserInterface: false,
      cancelNotification: true,
    );

    const snoozeAction = AndroidNotificationAction(
      'snooze',
      '10분 후',
      icon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      showsUserInterface: false,
      cancelNotification: true,
    );

    const androidDetails = AndroidNotificationDetails(
      'remindme_alarm_channel',
      '알람 알림',
      channelDescription: 'RemindMe 알람 알림을 위한 채널',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
      actions: [completeAction, snoozeAction], // 완료, 스누즈 버튼 추가
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      visibility: NotificationVisibility.public,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      categoryIdentifier: 'alarmCategory',
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.zonedSchedule(
      id,
      '리마인드 알람!',
      content,
      tzTime,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // 매일 반복
      payload: payload,
    );
  }

  Future<void> cancelAlarm(int id) async {
    await _notifications.cancel(id);
  }

  Future<void> cancelAllAlarms() async {
    await _notifications.cancelAll();
  }

  Future<List<PendingNotificationRequest>> getPendingAlarms() async {
    return await _notifications.pendingNotificationRequests();
  }

  /// 스누즈 알람 (지정된 시간 후 다시 알림)
  Future<void> snoozeAlarm({
    required int id,
    required String alarmId,
    required String content,
    int snoozeMinutes = 10,
  }) async {
    try {
      final snoozeTime = DateTime.now().add(Duration(minutes: snoozeMinutes));
      final tzTime = tz.TZDateTime.from(snoozeTime, tz.local);

      final payload = jsonEncode({
        'alarmId': alarmId,
        'content': content,
      });

      const completeAction = AndroidNotificationAction(
        'complete',
        '완료',
        showsUserInterface: false,
        cancelNotification: true,
      );

      const snoozeAgainAction = AndroidNotificationAction(
        'snooze',
        '다시 10분',
        showsUserInterface: false,
        cancelNotification: true,
      );

      const androidDetails = AndroidNotificationDetails(
        'remindme_alarm_channel',
        '알람 알림',
        channelDescription: 'RemindMe 알람 알림을 위한 채널',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
        actions: [completeAction, snoozeAgainAction],
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        categoryIdentifier: 'alarmCategory',
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.zonedSchedule(
        id + 100000, // 다른 ID 사용 (충돌 방지)
        '스누즈 알람',
        content,
        tzTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );

      print('스누즈 설정: ${snoozeMinutes}분 후 ($snoozeTime)');
    } catch (e) {
      print('스누즈 설정 실패: $e');
      rethrow;
    }
  }
}
