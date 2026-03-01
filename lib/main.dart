import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
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

  // 알림 서비스 초기화
  await NotificationService().initialize();

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
      home: const RemindMeHomeScreen(),
    );
  }
}
