import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
import 'models/alarm_item.dart';
import 'screens/main_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/chaos_alarm_screen.dart';
import 'screens/mood_alarm_screen.dart';
import 'services/notification_service.dart';
import 'services/alarm_service.dart';
import 'services/settings_service.dart';

final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('ko', null);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Sign in anonymously for guest mode
  if (FirebaseAuth.instance.currentUser == null) {
    try {
      await FirebaseAuth.instance.signInAnonymously();
    } catch (_) {
      // Anonymous auth disabled in Firebase Console — app runs in guest mode.
    }
  }

  await NotificationService().initialize(
    onNotificationTapped: (alarmId, action, mode, content) async {
      if (action == 'complete') {
        await AlarmService().completeAlarm(alarmId);
      } else if (action == 'snooze') {
        await AlarmService().snoozeAlarm(alarmId, minutes: 10);
      } else {
        // 'open' — show the appropriate alarm screen
        final alarmMode = AlarmMode.values.firstWhere(
          (m) => m.name == mode,
          orElse: () => AlarmMode.chaos,
        );
        switch (alarmMode) {
          case AlarmMode.chaos:
            navigatorKey.currentState?.push(
              MaterialPageRoute(
                builder: (_) =>
                    ChaosAlarmScreen(alarmId: alarmId, content: content),
              ),
            );
          case AlarmMode.mood:
            navigatorKey.currentState?.push(
              MaterialPageRoute(
                builder: (_) =>
                    MoodAlarmScreen(alarmId: alarmId, content: content),
              ),
            );
          case AlarmMode.ghost:
            // Silent — just mark complete silently
            await AlarmService().completeAlarm(alarmId);
        }
      }
    },
  );

  await AlarmService().restoreAlarmsAfterReboot();

  final onboardingDone = await SettingsService().isOnboardingDone();

  runApp(RemindMeApp(showOnboarding: !onboardingDone));
}

class RemindMeApp extends StatelessWidget {
  final bool showOnboarding;
  const RemindMeApp({super.key, this.showOnboarding = false});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Remind Me',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
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
        colorScheme:
            ColorScheme.fromSeed(
              seedColor: const Color(0xFF7C3AED),
              brightness: Brightness.dark,
            ).copyWith(
              surface: const Color(0xFF0F0F14),
              surfaceContainerHighest: const Color(0xFF1C1C25),
            ),
        scaffoldBackgroundColor: const Color(0xFF0F0F14),
      ),
      home: showOnboarding ? const OnboardingScreen() : const MainScreen(),
    );
  }
}
