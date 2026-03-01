import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
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
      onDidReceiveNotificationResponse: (details) {
        // 알림 클릭 시 처리
        print('Notification clicked: ${details.payload}');
      },
    );

    // 알림 채널 생성 (Android 8.0 이상)
    await _createNotificationChannel();
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

    const androidDetails = AndroidNotificationDetails(
      'remindme_alarm_channel',
      '알람 알림',
      channelDescription: 'RemindMe 알람 알림을 위한 채널',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.zonedSchedule(
      id,
      '알람이 울립니다!',
      content,
      tzTime,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // 매일 반복
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
}
