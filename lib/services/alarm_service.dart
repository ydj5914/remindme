import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/alarm_item.dart';
import 'notification_service.dart';

class AlarmService {
  static final AlarmService _instance = AlarmService._internal();
  factory AlarmService() => _instance;
  AlarmService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();

  String? get _userId => _auth.currentUser?.uid;

  CollectionReference get _alarmsCollection {
    if (_userId == null) {
      throw Exception('사용자가 로그인되어 있지 않습니다');
    }
    return _firestore.collection('users').doc(_userId).collection('alarms');
  }

  /// Firestore에 알람 저장 + 로컬 알람 스케줄링
  Future<String> addAlarm({
    required String content,
    required DateTime scheduledTime,
  }) async {
    try {
      final alarm = AlarmItem(
        id: '', // Firestore에서 자동 생성
        time: scheduledTime,
        content: content,
        isActive: true,
      );

      // 1. Firestore에 저장
      final docRef = await _alarmsCollection.add(alarm.toMap());

      // 2. 로컬 알람 스케줄링
      await _notificationService.scheduleAlarm(
        id: alarm.notificationId,
        title: 'Remind Me',
        content: content,
        scheduledTime: scheduledTime,
      );

      return docRef.id;
    } catch (e) {
      throw Exception('알람 추가 실패: $e');
    }
  }

  /// 알람 삭제 (Firestore + 로컬)
  Future<void> deleteAlarm(AlarmItem alarm) async {
    try {
      // 1. Firestore에서 삭제
      await _alarmsCollection.doc(alarm.id).delete();

      // 2. 로컬 알람 취소
      await _notificationService.cancelAlarm(alarm.notificationId);
    } catch (e) {
      throw Exception('알람 삭제 실패: $e');
    }
  }

  /// 알람 활성/비활성 토글
  Future<void> toggleAlarm(AlarmItem alarm) async {
    try {
      final newStatus = !alarm.isActive;

      // 1. Firestore 업데이트
      await _alarmsCollection.doc(alarm.id).update({'isActive': newStatus});

      // 2. 로컬 알람 처리
      if (newStatus) {
        // 활성화: 다시 스케줄링
        await _notificationService.scheduleAlarm(
          id: alarm.notificationId,
          title: 'Remind Me',
          content: alarm.content,
          scheduledTime: alarm.time,
        );
      } else {
        // 비활성화: 취소
        await _notificationService.cancelAlarm(alarm.notificationId);
      }
    } catch (e) {
      throw Exception('알람 토글 실패: $e');
    }
  }

  /// Firestore에서 모든 알람 가져오기 (실시간 스트림)
  Stream<List<AlarmItem>> getAlarmsStream() {
    if (_userId == null) {
      return Stream.value([]);
    }

    return _alarmsCollection
        .orderBy('timeMillis')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => AlarmItem.fromMap(doc.id, doc.data() as Map<String, dynamic>))
          .toList();
    });
  }

  /// Firestore에서 활성화된 알람만 가져오기
  Future<List<AlarmItem>> getActiveAlarms() async {
    if (_userId == null) {
      return [];
    }

    try {
      final snapshot = await _alarmsCollection
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => AlarmItem.fromMap(doc.id, doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('활성 알람 조회 실패: $e');
      return [];
    }
  }

  /// 재부팅 후 알람 복원 (앱 시작 시 호출)
  Future<void> restoreAlarmsAfterReboot() async {
    if (_userId == null) {
      print('사용자가 로그인되어 있지 않아 알람을 복원할 수 없습니다');
      return;
    }

    try {
      print('알람 복원 시작...');

      // 1. Firestore에서 활성화된 알람 목록 가져오기
      final activeAlarms = await getActiveAlarms();
      print('복원할 알람 ${activeAlarms.length}개 발견');

      // 2. 로컬 알람 모두 취소 (중복 방지)
      await _notificationService.cancelAllAlarms();

      // 3. 각 알람을 다시 스케줄링
      for (final alarm in activeAlarms) {
        try {
          await _notificationService.scheduleAlarm(
            id: alarm.notificationId,
            title: 'Remind Me',
            content: alarm.content,
            scheduledTime: alarm.time,
          );
          print('알람 복원 성공: ${alarm.content} at ${alarm.time}');
        } catch (e) {
          print('알람 복원 실패: ${alarm.content}, 오류: $e');
        }
      }

      print('알람 복원 완료');
    } catch (e) {
      print('알람 복원 중 오류 발생: $e');
    }
  }

  /// 알람 동기화 (Firestore와 로컬 알람 일치시키기)
  Future<void> syncAlarms() async {
    await restoreAlarmsAfterReboot();
  }
}
