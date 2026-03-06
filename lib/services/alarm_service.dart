import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/alarm_item.dart';
import 'notification_service.dart';
import 'settings_service.dart';
import 'widget_service.dart';

class AlarmService {
  static final AlarmService _instance = AlarmService._internal();
  factory AlarmService() => _instance;
  AlarmService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();

  // Local stream controller for guest mode
  final _localAlarmsController = StreamController<List<AlarmItem>>.broadcast();
  final _localHistoryController = StreamController<List<AlarmItem>>.broadcast();

  static const _localAlarmsKey = 'local_alarms';
  static const _permissionAskedKey = 'permission_asked';

  String? get _userId => _auth.currentUser?.uid;

  /// Guest = no user, anonymous user, OR any state where we can't reach Firestore.
  bool get _isGuest {
    final user = _auth.currentUser;
    if (user == null) return true;
    if (user.isAnonymous) return true;
    // If uid exists but no network, we still treat as guest to avoid crashes.
    return false;
  }

  CollectionReference get _alarmsCollection {
    if (_userId == null) throw Exception('Not signed in');
    return _firestore.collection('users').doc(_userId).collection('alarms');
  }

  // ─── Permission ───────────────────────────────────────────────────────────

  /// Request permission on first alarm creation.
  Future<void> _requestPermissionIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final asked = prefs.getBool(_permissionAskedKey) ?? false;
    if (!asked) {
      await _notificationService.requestPermissions();
      await prefs.setBool(_permissionAskedKey, true);
    }
  }

  // ─── Local Storage helpers ────────────────────────────────────────────────

  Future<List<AlarmItem>> _loadLocalAlarms() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_localAlarmsKey) ?? [];
    return raw.map((s) {
      final map = jsonDecode(s) as Map<String, dynamic>;
      return AlarmItem.fromMap(map['id'] as String, map);
    }).toList();
  }

  Future<void> _saveLocalAlarms(List<AlarmItem> alarms) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = alarms.map((a) {
      final map = a.toMap();
      map['id'] = a.id;
      return jsonEncode(map);
    }).toList();
    await prefs.setStringList(_localAlarmsKey, raw);
    // Push to local stream
    final active = alarms.where((a) => a.completedAt == null).toList();
    final history = alarms.where((a) => a.completedAt != null).toList();
    _localAlarmsController.add(active);
    _localHistoryController.add(history);
  }

  String _generateLocalId() => 'local_${DateTime.now().millisecondsSinceEpoch}';

  // ─── Add Alarm ─────────────────────────────────────────────────────────────

  Future<String> addAlarm({
    required String content,
    required DateTime scheduledTime,
  }) => addAlarmWithRepeat(
    content: content,
    scheduledTime: scheduledTime,
    repeatType: RepeatType.daily,
  );

  Future<String> addAlarmWithRepeat({
    required String content,
    required DateTime scheduledTime,
    required RepeatType repeatType,
    List<int>? customDays,
    AlarmSoundOption sound = AlarmSoundOption.defaultSound,
    AlarmMode mode = AlarmMode.chaos,
  }) async {
    // Request notification permission on first alarm
    await _requestPermissionIfNeeded();

    final alarm = AlarmItem(
      id: '',
      time: scheduledTime,
      content: content,
      isActive: true,
      repeatType: repeatType,
      customDays: customDays,
      mode: mode,
    );

    String docId;

    if (_isGuest) {
      // ── Guest: store locally ──────────────────────────────────────────
      docId = _generateLocalId();
      final alarmWithId = alarm.copyWith(id: docId);
      final all = await _loadLocalAlarms();
      all.add(alarmWithId);
      await _saveLocalAlarms(all);
    } else {
      // ── Logged-in: store in Firestore ─────────────────────────────────
      final ref = await _alarmsCollection.add(alarm.toMap());
      docId = ref.id;
    }

    // Schedule local notification (works for both modes)
    await _notificationService.scheduleAlarm(
      id: scheduledTime.millisecondsSinceEpoch ~/ 1000,
      alarmId: docId,
      title: 'Remind Me',
      content: content,
      scheduledTime: scheduledTime,
      repeatType: repeatType,
      customDays: customDays,
      sound: sound,
      mode: mode,
    );

    // Refresh home widget
    unawaited(WidgetService().updateWidget());

    return docId;
  }

  // ─── Delete ────────────────────────────────────────────────────────────────

  Future<void> deleteAlarm(AlarmItem alarm) async {
    if (_isGuest) {
      final all = await _loadLocalAlarms();
      all.removeWhere((a) => a.id == alarm.id);
      await _saveLocalAlarms(all);
    } else {
      await _alarmsCollection.doc(alarm.id).delete();
    }
    await _notificationService.cancelAlarm(alarm.notificationId);
  }

  // ─── Toggle ────────────────────────────────────────────────────────────────

  Future<void> toggleAlarm(AlarmItem alarm) async {
    final newStatus = !alarm.isActive;

    if (_isGuest) {
      final all = await _loadLocalAlarms();
      final idx = all.indexWhere((a) => a.id == alarm.id);
      if (idx != -1) {
        all[idx] = alarm.copyWith(isActive: newStatus);
        await _saveLocalAlarms(all);
      }
    } else {
      await _alarmsCollection.doc(alarm.id).update({'isActive': newStatus});
    }

    if (newStatus) {
      await _notificationService.scheduleAlarm(
        id: alarm.notificationId,
        alarmId: alarm.id,
        title: 'Remind Me',
        content: alarm.content,
        scheduledTime: alarm.time,
        repeatType: alarm.repeatType,
        customDays: alarm.customDays,
        mode: alarm.mode,
      );
    } else {
      await _notificationService.cancelAlarm(alarm.notificationId);
    }
  }

  // ─── Complete ─────────────────────────────────────────────────────────────

  Future<void> completeAlarm(String alarmId) async {
    unawaited(WidgetService().updateWidget());
    final now = DateTime.now().millisecondsSinceEpoch;

    if (_isGuest) {
      final all = await _loadLocalAlarms();
      final idx = all.indexWhere((a) => a.id == alarmId);
      if (idx == -1) return;
      final alarm = all[idx];
      if (alarm.repeatType == RepeatType.once) {
        all[idx] = alarm.copyWith(isActive: false, completedAt: DateTime.now());
      } else {
        all[idx] = alarm.copyWith(completedAt: DateTime.now());
      }
      await _saveLocalAlarms(all);
    } else {
      if (_userId == null) return;
      final doc = await _alarmsCollection.doc(alarmId).get();
      if (!doc.exists) return;
      final alarm = AlarmItem.fromMap(
        doc.id,
        doc.data() as Map<String, dynamic>,
      );
      if (alarm.repeatType == RepeatType.once) {
        await _alarmsCollection.doc(alarmId).update({
          'isActive': false,
          'completedAt': now,
        });
        await _notificationService.cancelAlarm(alarm.notificationId);
      } else {
        await _alarmsCollection.doc(alarmId).update({'completedAt': now});
      }
    }
  }

  // ─── Streams ───────────────────────────────────────────────────────────────

  Stream<List<AlarmItem>> getAlarmsStream() {
    if (_isGuest) {
      // Seed the stream with current data, then return the broadcast stream
      _loadLocalAlarms().then((all) {
        _localAlarmsController.add(
          all.where((a) => a.completedAt == null).toList(),
        );
      });
      return _localAlarmsController.stream;
    }

    return _alarmsCollection
        .where('completedAt', isNull: true)
        .orderBy('timeMillis')
        .snapshots()
        .map(
          (s) => s.docs
              .map(
                (d) =>
                    AlarmItem.fromMap(d.id, d.data() as Map<String, dynamic>),
              )
              .toList(),
        );
  }

  Stream<List<AlarmItem>> getHistoryStream() {
    if (_isGuest) {
      _loadLocalAlarms().then((all) {
        final history = all.where((a) => a.completedAt != null).toList()
          ..sort(
            (a, b) => (b.completedAt ?? DateTime(0)).compareTo(
              a.completedAt ?? DateTime(0),
            ),
          );
        _localHistoryController.add(history);
      });
      return _localHistoryController.stream;
    }

    if (_userId == null) return Stream.value([]);
    return _alarmsCollection
        .where('completedAt', isNull: false)
        .orderBy('completedAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (s) => s.docs
              .map(
                (d) =>
                    AlarmItem.fromMap(d.id, d.data() as Map<String, dynamic>),
              )
              .toList(),
        );
  }

  // ─── History helpers ───────────────────────────────────────────────────────

  Future<void> deleteHistory(AlarmItem alarm) async {
    if (_isGuest) {
      final all = await _loadLocalAlarms();
      all.removeWhere((a) => a.id == alarm.id);
      await _saveLocalAlarms(all);
    } else {
      await _alarmsCollection.doc(alarm.id).delete();
    }
  }

  Future<void> clearHistory() async {
    if (_isGuest) {
      final all = await _loadLocalAlarms();
      all.removeWhere((a) => a.completedAt != null);
      await _saveLocalAlarms(all);
    } else {
      if (_userId == null) return;
      final snapshot = await _alarmsCollection
          .where('completedAt', isNull: false)
          .get();
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) batch.delete(doc.reference);
      await batch.commit();
    }
  }

  Future<void> updateHistoryNote(String alarmId, String note) async {
    if (_isGuest) {
      final all = await _loadLocalAlarms();
      final idx = all.indexWhere((a) => a.id == alarmId);
      if (idx != -1) {
        all[idx] = all[idx].copyWith(note: note);
        await _saveLocalAlarms(all);
      }
    } else {
      await _alarmsCollection.doc(alarmId).update({'note': note});
    }
  }

  // ─── Counts & queries ─────────────────────────────────────────────────────

  Future<int> getAlarmCount() async {
    if (_isGuest) {
      final all = await _loadLocalAlarms();
      return all.where((a) => a.completedAt == null).length;
    }
    if (_userId == null) return 0;
    final snapshot = await _alarmsCollection
        .where('completedAt', isNull: true)
        .get();
    return snapshot.docs.length;
  }

  Future<List<AlarmItem>> getActiveAlarms() async {
    if (_isGuest) {
      final all = await _loadLocalAlarms();
      return all.where((a) => a.isActive && a.completedAt == null).toList();
    }
    if (_userId == null) return [];
    final snapshot = await _alarmsCollection
        .where('isActive', isEqualTo: true)
        .get();
    return snapshot.docs
        .map((d) => AlarmItem.fromMap(d.id, d.data() as Map<String, dynamic>))
        .toList();
  }

  // ─── Sync / Restore ───────────────────────────────────────────────────────

  Future<void> restoreAlarmsAfterReboot() async {
    final activeAlarms = await getActiveAlarms();
    await _notificationService.cancelAllAlarms();
    for (final alarm in activeAlarms) {
      try {
        await _notificationService.scheduleAlarm(
          id: alarm.notificationId,
          alarmId: alarm.id,
          title: 'Remind Me',
          content: alarm.content,
          scheduledTime: alarm.time,
          repeatType: alarm.repeatType,
          customDays: alarm.customDays,
          mode: alarm.mode,
        );
      } catch (_) {}
    }
  }

  Future<void> syncAlarms() => restoreAlarmsAfterReboot();

  Future<void> snoozeAlarm(String alarmId, {int minutes = 10}) async {
    AlarmItem? alarm;

    if (_isGuest) {
      final all = await _loadLocalAlarms();
      alarm = all.cast<AlarmItem?>().firstWhere(
        (a) => a?.id == alarmId,
        orElse: () => null,
      );
    } else {
      if (_userId == null) return;
      final doc = await _alarmsCollection.doc(alarmId).get();
      if (!doc.exists) return;
      alarm = AlarmItem.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      await _alarmsCollection.doc(alarmId).update({
        'snoozeCount': alarm.snoozeCount + 1,
      });
    }

    if (alarm == null) return;
    await _notificationService.snoozeAlarm(
      id: alarm.notificationId,
      alarmId: alarmId,
      content: alarm.content,
      snoozeMinutes: minutes,
    );
  }

  // ─── Smart Snooze (escalating) ────────────────────────────────────────────

  /// Call this when a Chaos alarm fires and the screen is shown.
  /// Schedules escalating follow-up notifications in case the user ignores it.
  Future<void> startEscalatingFollowUps(String alarmId) async {
    AlarmItem? alarm;
    if (_isGuest) {
      final all = await _loadLocalAlarms();
      alarm = all.cast<AlarmItem?>().firstWhere(
        (a) => a?.id == alarmId,
        orElse: () => null,
      );
    } else {
      if (_userId == null) return;
      final doc = await _alarmsCollection.doc(alarmId).get();
      if (!doc.exists) return;
      alarm = AlarmItem.fromMap(doc.id, doc.data() as Map<String, dynamic>);
    }
    if (alarm == null) return;

    final intense = await SettingsService().isChaosIntenseEnabled();
    await _notificationService.scheduleEscalatingFollowUps(
      baseId: alarm.notificationId,
      alarmId: alarmId,
      content: alarm.content,
      intervalMinutes: intense ? 3 : 5,
    );
  }

  /// Cancel escalating follow-ups (called when alarm is dismissed/completed).
  Future<void> cancelEscalatingFollowUps(String alarmId) async {
    AlarmItem? alarm;
    if (_isGuest) {
      final all = await _loadLocalAlarms();
      alarm = all.cast<AlarmItem?>().firstWhere(
        (a) => a?.id == alarmId,
        orElse: () => null,
      );
    } else {
      if (_userId == null) return;
      final doc = await _alarmsCollection.doc(alarmId).get();
      if (doc.exists) {
        alarm = AlarmItem.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }
    }
    if (alarm != null) {
      await _notificationService.cancelEscalatingFollowUps(
        alarm.notificationId,
      );
    }
  }

  // ─── Backup reminder ──────────────────────────────────────────────────────

  /// Returns true if a guest user should be shown the backup reminder.
  /// Triggered when alarms ≥ 10 OR history ≥ 20.
  Future<bool> shouldShowBackupReminder() async {
    if (!_isGuest) return false;
    final shouldShow = await SettingsService().shouldShowBackupReminder();
    if (!shouldShow) return false;
    final all = await _loadLocalAlarms();
    final activeCount = all.where((a) => a.completedAt == null).length;
    final historyCount = all.where((a) => a.completedAt != null).length;
    return activeCount >= 10 || historyCount >= 20;
  }

  Future<void> markBackupReminderShown() =>
      SettingsService().markBackupReminderShown();

  // ─── Data migration (guest → account) ────────────────────────────────────

  /// Call after successful linkWithCredential to push local alarms to Firestore.
  Future<void> migrateLocalAlarmsToFirestore() async {
    if (_userId == null) return;
    final localAlarms = await _loadLocalAlarms();
    if (localAlarms.isEmpty) return;

    final batch = _firestore.batch();
    for (final alarm in localAlarms) {
      final ref = _alarmsCollection.doc();
      batch.set(ref, alarm.toMap());
    }
    await batch.commit();

    // Clear local storage after migration
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_localAlarmsKey);
  }
}
