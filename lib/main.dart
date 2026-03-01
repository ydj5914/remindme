import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
import 'screens/main_screen.dart';
import 'services/notification_service.dart';
import 'services/alarm_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 날짜 포맷 초기화 (한국어)
  await initializeDateFormatting('ko', null);

  // Firebase 초기화
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 알림 서비스 초기화 (알림 클릭 콜백 포함)
  await NotificationService().initialize(
    onNotificationTapped: (alarmId, action) async {
      print('Notification tapped: alarmId=$alarmId, action=$action');

      // 익명 로그인이 되어있지 않으면 로그인 먼저
      if (FirebaseAuth.instance.currentUser == null) {
        await _signInAnonymously();
      }

      // 액션에 따라 처리
      if (action == 'complete' || action == 'open') {
        // 완료 처리
        await AlarmService().completeAlarm(alarmId);
      } else if (action == 'snooze') {
        // 스누즈 처리
        await AlarmService().snoozeAlarm(alarmId, minutes: 10);
      }
    },
  );

  // 익명 로그인 (사용자 인증)
  await _signInAnonymously();

  // 재부팅 후 알람 복원
  await AlarmService().restoreAlarmsAfterReboot();

  runApp(const RemindMeApp());
}

Future<void> _signInAnonymously() async {
  try {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      await auth.signInAnonymously();
      print('익명 로그인 성공');
    } else {
      print('이미 로그인됨: ${auth.currentUser?.uid}');
    }
  } catch (e) {
    print('익명 로그인 실패: $e');
  }
}

class RemindMeApp extends StatelessWidget {
  const RemindMeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Remind Me',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
      ),
      home: const MainScreen(),
    );
  }
}
