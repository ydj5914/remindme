import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  static const _hapticsKey = 'settings_haptics';
  static const _soundKey = 'settings_sound';
  static const _chaosIntenseKey = 'settings_chaos_intense';
  static const _onboardingDoneKey = 'onboarding_done';
  static const _backupShownKey = 'backup_reminder_shown';
  static const _firstCompletionKey = 'first_completion_done';

  // ── Haptics ────────────────────────────────────────────────────────────────

  Future<bool> isHapticsEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_hapticsKey) ?? true;
  }

  Future<void> setHapticsEnabled(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_hapticsKey, v);
  }

  // ── Sound ─────────────────────────────────────────────────────────────────

  Future<bool> isSoundEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_soundKey) ?? true;
  }

  Future<void> setSoundEnabled(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_soundKey, v);
  }

  // ── Chaos Intense Mode ────────────────────────────────────────────────────
  // Escalates follow-up notifications every 3 min (vs default 5 min) and
  // uses a more aggressive vibration pattern.

  Future<bool> isChaosIntenseEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_chaosIntenseKey) ?? false;
  }

  Future<void> setChaosIntenseEnabled(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_chaosIntenseKey, v);
  }

  // ── Onboarding ────────────────────────────────────────────────────────────

  Future<bool> isOnboardingDone() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_onboardingDoneKey) ?? false;
  }

  Future<void> setOnboardingDone() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_onboardingDoneKey, true);
  }

  // ── Backup reminder ───────────────────────────────────────────────────────

  Future<bool> shouldShowBackupReminder() async {
    final p = await SharedPreferences.getInstance();
    return !(p.getBool(_backupShownKey) ?? false);
  }

  Future<void> markBackupReminderShown() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_backupShownKey, true);
  }

  // ── First completion ──────────────────────────────────────────────────────

  /// Returns true the very first time an alarm is completed.
  /// Automatically marks it as done so it won't trigger again.
  Future<bool> checkAndMarkFirstCompletion() async {
    final p = await SharedPreferences.getInstance();
    final done = p.getBool(_firstCompletionKey) ?? false;
    if (done) return false;
    await p.setBool(_firstCompletionKey, true);
    return true;
  }
}
