import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../models/alarm_item.dart';

// Notification channel IDs
const _kAlarmChannelId = 'remindme_alarm_channel';
const _kGhostChannelId = 'remindme_ghost_channel';

/// Sound options for alarms.
/// To add a custom sound:
///   iOS  → add <name>.aiff / .wav / .caf to ios/Runner/Sounds/ and Xcode bundle
///   Android → add <name>.mp3 to android/app/src/main/res/raw/
enum AlarmSoundOption {
  defaultSound, // system default
  gentle, // gentle.caf (custom)
  digital, // digital.caf (custom)
  nature, // nature.caf (custom)
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  Function(String alarmId, String action, String mode, String content)?
  onNotificationTapped;

  bool _initialized = false;
  bool _permissionGranted = false;

  // ─── Initialise ──────────────────────────────────────────────────────────

  Future<void> initialize({
    Function(String alarmId, String action, String mode, String content)?
    onNotificationTapped,
  }) async {
    if (_initialized) return;
    this.onNotificationTapped = onNotificationTapped;

    tz.initializeTimeZones();
    _setLocalTimezone();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    final iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false, // we request manually on first alarm
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: <DarwinNotificationCategory>[
        DarwinNotificationCategory(
          'alarmCategory',
          actions: <DarwinNotificationAction>[
            DarwinNotificationAction.plain(
              'complete',
              'Done ✓',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
            DarwinNotificationAction.plain(
              'snooze',
              'Snooze 10m',
              options: <DarwinNotificationActionOption>{},
            ),
          ],
        ),
      ],
    );

    await _notifications.initialize(
      InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _handleResponse,
      onDidReceiveBackgroundNotificationResponse: _handleBackgroundResponse,
    );

    await _createAndroidChannels();
    _initialized = true;
  }

  void _setLocalTimezone() {
    try {
      // Tries to set local timezone; falls back to UTC on failure
      tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
  }

  // ─── Permissions ────────────────────────────────────────────────────────

  /// Call this explicitly when the user creates their FIRST alarm.
  Future<bool> requestPermissions() async {
    // iOS — ask via flutter_local_notifications
    final iosImpl = _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (iosImpl != null) {
      final granted = await iosImpl.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
        critical: false,
      );
      _permissionGranted = granted ?? false;
      return _permissionGranted;
    }

    // Android 13+
    final status = await Permission.notification.status;
    if (status.isDenied) {
      final result = await Permission.notification.request();
      _permissionGranted = result.isGranted;
      return _permissionGranted;
    }
    _permissionGranted = status.isGranted;
    return _permissionGranted;
  }

  Future<bool> hasPermission() async {
    final status = await Permission.notification.status;
    return status.isGranted;
  }

  // ─── Schedule ────────────────────────────────────────────────────────────

  /// Schedule a local alarm notification.
  /// Handles all RepeatType variants and optional custom sound.
  Future<void> scheduleAlarm({
    required int id,
    required String alarmId,
    required String title,
    required String content,
    required DateTime scheduledTime,
    RepeatType repeatType = RepeatType.daily,
    List<int>? customDays,
    AlarmSoundOption sound = AlarmSoundOption.defaultSound,
    AlarmMode mode = AlarmMode.chaos,
  }) async {
    if (!await hasPermission()) {
      final granted = await requestPermissions();
      if (!granted) throw Exception('Notification permission is required');
    }

    final payload = jsonEncode({
      'alarmId': alarmId,
      'content': content,
      'mode': mode.name,
    });
    final details = _buildNotificationDetails(content, sound, mode);

    switch (repeatType) {
      case RepeatType.once:
        await _scheduleOnce(
          id,
          title,
          content,
          scheduledTime,
          details,
          payload,
        );

      case RepeatType.daily:
        await _scheduleRepeating(
          id,
          title,
          content,
          scheduledTime,
          DateTimeComponents.time,
          details,
          payload,
        );

      case RepeatType.weekdays:
        // Schedule Mon–Fri individually (ids: id+0 … id+4)
        for (int day = 1; day <= 5; day++) {
          final next = _nextWeekday(scheduledTime, day);
          await _scheduleRepeating(
            id + day,
            title,
            content,
            next,
            DateTimeComponents.dayOfWeekAndTime,
            details,
            payload,
          );
        }

      case RepeatType.weekends:
        // Schedule Sat (6) and Sun (7)
        for (int day in [6, 7]) {
          final next = _nextWeekday(scheduledTime, day);
          await _scheduleRepeating(
            id + day,
            title,
            content,
            next,
            DateTimeComponents.dayOfWeekAndTime,
            details,
            payload,
          );
        }

      case RepeatType.custom:
        final days = customDays ?? [];
        for (final day in days) {
          // customDays: 0=Mon, …, 6=Sun → DateTime.weekday: 1=Mon, …, 7=Sun
          final next = _nextWeekday(scheduledTime, day + 1);
          await _scheduleRepeating(
            id + day + 10,
            title,
            content,
            next,
            DateTimeComponents.dayOfWeekAndTime,
            details,
            payload,
          );
        }
    }
  }

  // ─── Escalating Follow-ups (Smart Snooze) ────────────────────────────────

  /// Called right after a Chaos alarm fires (from the notification tap handler).
  /// Schedules up to 5 follow-up notifications with escalating vibration,
  /// spaced [intervalMinutes] apart.  Each follow-up uses a base ID offset
  /// of 200000 + step * 1000 to avoid collisions.
  Future<void> scheduleEscalatingFollowUps({
    required int baseId,
    required String alarmId,
    required String content,
    int intervalMinutes = 5,
  }) async {
    const maxSteps = 5;
    final now = tz.TZDateTime.now(tz.local);
    final payload = jsonEncode({
      'alarmId': alarmId,
      'content': content,
      'mode': 'chaos',
    });

    for (int step = 1; step <= maxSteps; step++) {
      final fireTime = now.add(Duration(minutes: intervalMinutes * step));
      // Vibration pattern becomes more intense at each step
      final pattern = _escalatingVibration(step);
      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          _kAlarmChannelId,
          'Alarm Notifications',
          channelDescription: 'RemindMe scheduled alarm alerts',
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          enableVibration: true,
          vibrationPattern: pattern,
          icon: '@mipmap/ic_launcher',
          category: AndroidNotificationCategory.alarm,
          fullScreenIntent: true,
          visibility: NotificationVisibility.public,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.critical,
        ),
      );
      await _notifications.zonedSchedule(
        200000 + step * 1000 + baseId % 1000,
        'Still awake? ⚡',
        content,
        fireTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    }
  }

  Int64List _escalatingVibration(int step) {
    // Each step doubles the burst count and shortens the gap
    switch (step) {
      case 1:
        return Int64List.fromList([0, 400, 200, 400]);
      case 2:
        return Int64List.fromList([0, 400, 150, 400, 150, 400]);
      case 3:
        return Int64List.fromList([0, 500, 100, 500, 100, 500, 100, 500]);
      case 4:
        return Int64List.fromList([0, 600, 80, 600, 80, 600, 80, 600, 80, 600]);
      default:
        return Int64List.fromList([
          0,
          800,
          50,
          800,
          50,
          800,
          50,
          800,
          50,
          800,
          50,
          800,
        ]);
    }
  }

  /// Cancel all escalating follow-up notifications for a base ID.
  Future<void> cancelEscalatingFollowUps(int baseId) async {
    for (int step = 1; step <= 5; step++) {
      await _notifications.cancel(200000 + step * 1000 + baseId % 1000);
    }
  }

  Future<void> _scheduleOnce(
    int id,
    String title,
    String content,
    DateTime scheduledTime,
    NotificationDetails details,
    String payload,
  ) async {
    var target = scheduledTime;
    if (target.isBefore(DateTime.now())) {
      target = target.add(const Duration(days: 1));
    }
    await _notifications.zonedSchedule(
      id,
      title,
      content,
      tz.TZDateTime.from(target, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  Future<void> _scheduleRepeating(
    int id,
    String title,
    String content,
    DateTime scheduledTime,
    DateTimeComponents components,
    NotificationDetails details,
    String payload,
  ) async {
    await _notifications.zonedSchedule(
      id,
      title,
      content,
      tz.TZDateTime.from(scheduledTime, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: components,
      payload: payload,
    );
  }

  /// Returns the next occurrence of [weekday] (1=Mon … 7=Sun) at the
  /// hour/minute of [base].
  DateTime _nextWeekday(DateTime base, int weekday) {
    final now = DateTime.now();
    var candidate = DateTime(
      now.year,
      now.month,
      now.day,
      base.hour,
      base.minute,
    );
    // Move to the correct weekday
    while (candidate.weekday != weekday) {
      candidate = candidate.add(const Duration(days: 1));
    }
    if (candidate.isBefore(now)) {
      candidate = candidate.add(const Duration(days: 7));
    }
    return candidate;
  }

  // ─── Notification Details ────────────────────────────────────────────────

  NotificationDetails _buildNotificationDetails(
    String body,
    AlarmSoundOption sound,
    AlarmMode mode,
  ) {
    if (mode == AlarmMode.ghost) {
      return _buildGhostNotificationDetails();
    }
    final androidSound = _androidSound(sound);
    final iosSound = _iosSound(sound);

    final androidDetails = AndroidNotificationDetails(
      _kAlarmChannelId,
      'Alarm Notifications',
      channelDescription: 'RemindMe scheduled alarm alerts',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList(<int>[0, 400, 200, 400]),
      sound: androidSound,
      icon: '@mipmap/ic_launcher',
      actions: const [
        AndroidNotificationAction(
          'complete',
          'Done ✓',
          showsUserInterface: false,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          'snooze',
          'Snooze 10m',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      visibility: NotificationVisibility.public,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: iosSound,
      categoryIdentifier: 'alarmCategory',
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    return NotificationDetails(android: androidDetails, iOS: iosDetails);
  }

  NotificationDetails _buildGhostNotificationDetails() {
    const androidDetails = AndroidNotificationDetails(
      _kGhostChannelId,
      'Ghost Reminders',
      channelDescription: 'Silent RemindMe reminders',
      importance: Importance.low,
      priority: Priority.low,
      playSound: false,
      enableVibration: false,
      ongoing: true,
      icon: '@mipmap/ic_launcher',
      visibility: NotificationVisibility.public,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: false,
      interruptionLevel: InterruptionLevel.passive,
    );
    return const NotificationDetails(android: androidDetails, iOS: iosDetails);
  }

  /// Returns null (system default) or a RawResourceAndroidNotificationSound
  /// pointing to res/raw/<name>.mp3.
  AndroidNotificationSound? _androidSound(AlarmSoundOption option) {
    switch (option) {
      case AlarmSoundOption.defaultSound:
        return null;
      case AlarmSoundOption.gentle:
        return const RawResourceAndroidNotificationSound('alarm_gentle');
      case AlarmSoundOption.digital:
        return const RawResourceAndroidNotificationSound('alarm_digital');
      case AlarmSoundOption.nature:
        return const RawResourceAndroidNotificationSound('alarm_nature');
    }
  }

  /// Returns null (system default) or the filename (without extension) of a
  /// sound file bundled in ios/Runner/Sounds/.
  String? _iosSound(AlarmSoundOption option) {
    switch (option) {
      case AlarmSoundOption.defaultSound:
        return null;
      case AlarmSoundOption.gentle:
        return 'alarm_gentle.caf';
      case AlarmSoundOption.digital:
        return 'alarm_digital.caf';
      case AlarmSoundOption.nature:
        return 'alarm_nature.caf';
    }
  }

  // ─── Android Channel ─────────────────────────────────────────────────────

  Future<void> _createAndroidChannels() async {
    const alarmChannel = AndroidNotificationChannel(
      _kAlarmChannelId,
      'Alarm Notifications',
      description: 'RemindMe scheduled alarm alerts',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );
    const ghostChannel = AndroidNotificationChannel(
      _kGhostChannelId,
      'Ghost Reminders',
      description: 'Silent RemindMe reminders',
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
    );
    final plugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await plugin?.createNotificationChannel(alarmChannel);
    await plugin?.createNotificationChannel(ghostChannel);
  }

  // ─── Snooze ──────────────────────────────────────────────────────────────

  Future<void> snoozeAlarm({
    required int id,
    required String alarmId,
    required String content,
    int snoozeMinutes = 10,
  }) async {
    final snoozeTime = tz.TZDateTime.now(
      tz.local,
    ).add(Duration(minutes: snoozeMinutes));
    final payload = jsonEncode({
      'alarmId': alarmId,
      'content': content,
      'mode': 'chaos',
    });
    final details = _buildNotificationDetails(
      content,
      AlarmSoundOption.defaultSound,
      AlarmMode.chaos,
    );

    await _notifications.zonedSchedule(
      id + 100000,
      'Snoozed — ${content.length > 30 ? '${content.substring(0, 30)}…' : content}',
      'Your alarm is back!',
      snoozeTime,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  // ─── Cancel ──────────────────────────────────────────────────────────────

  Future<void> cancelAlarm(int id) async {
    // Cancel the main id + any weekday sub-ids (max 10 offsets used)
    await _notifications.cancel(id);
    for (int i = 1; i <= 17; i++) {
      await _notifications.cancel(id + i);
    }
  }

  Future<void> cancelAllAlarms() async => _notifications.cancelAll();

  Future<List<PendingNotificationRequest>> getPendingAlarms() =>
      _notifications.pendingNotificationRequests();

  // ─── Response handlers ───────────────────────────────────────────────────

  void _handleResponse(NotificationResponse response) {
    _dispatch(response.payload, response.actionId);
  }

  static void _handleBackgroundResponse(NotificationResponse response) {
    // Static — cannot access instance; FirebaseMessaging-style handling
    // would go here. For local notifications the action is persisted in
    // the payload and picked up on next app launch if needed.
  }

  void _dispatch(String? payload, String? actionId) {
    if (payload == null) return;
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final alarmId = data['alarmId'] as String;
      final content = data['content'] as String? ?? '';
      final mode = data['mode'] as String? ?? 'chaos';
      final action = actionId ?? 'open';
      onNotificationTapped?.call(alarmId, action, mode, content);
    } catch (_) {}
  }
}
