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

  await initializeDateFormatting('ko', null);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Sign in anonymously for guest mode
  if (FirebaseAuth.instance.currentUser == null) {
    try {
      await FirebaseAuth.instance.signInAnonymously();
    } catch (e) {
      // Anonymous auth may be disabled in Firebase Console.
      // App continues without a user — sign-in screen will be shown.
      debugPrint('Anonymous sign-in failed: $e');
    }
  }

  await NotificationService().initialize(
    onNotificationTapped: (alarmId, action) async {
      if (action == 'complete' || action == 'open') {
        await AlarmService().completeAlarm(alarmId);
      } else if (action == 'snooze') {
        await AlarmService().snoozeAlarm(alarmId, minutes: 10);
      }
    },
  );

  await AlarmService().restoreAlarmsAfterReboot();

  runApp(const RemindMeApp());
}

class RemindMeApp extends StatelessWidget {
  const RemindMeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Remind Me',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7C3AED),
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7C3AED),
          brightness: Brightness.dark,
        ).copyWith(
          surface: const Color(0xFF0F0F14),
          surfaceContainerHighest: const Color(0xFF1C1C25),
        ),
        scaffoldBackgroundColor: const Color(0xFF0F0F14),
      ),
      home: const MainScreen(),
    );
  }
}
