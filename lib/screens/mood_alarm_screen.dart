import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/alarm_service.dart';
import '../services/settings_service.dart';
import 'login_screen.dart';

enum MoodTheme { calm, cyberpunk, nature }

class MoodAlarmScreen extends StatefulWidget {
  final String alarmId;
  final String content;

  const MoodAlarmScreen({
    super.key,
    required this.alarmId,
    required this.content,
  });

  @override
  State<MoodAlarmScreen> createState() => _MoodAlarmScreenState();
}

class _MoodAlarmScreenState extends State<MoodAlarmScreen>
    with TickerProviderStateMixin {
  late AnimationController _gradientCtrl;
  late AnimationController _fadeCtrl;
  late AnimationController _clockCtrl;

  MoodTheme _mood = MoodTheme.calm;
  double _swipeDy = 0;
  bool _dismissing = false;

  static const _themes = {
    MoodTheme.calm: [
      [Color(0xFFB2EBF2), Color(0xFFE1BEE7)],
      [Color(0xFFF8BBD0), Color(0xFFDCEDC8)],
    ],
    MoodTheme.cyberpunk: [
      [Color(0xFF0D0D1A), Color(0xFF4A0080)],
      [Color(0xFF001A2E), Color(0xFF7C3AED)],
    ],
    MoodTheme.nature: [
      [Color(0xFF1B5E20), Color(0xFF4CAF50)],
      [Color(0xFF558B2F), Color(0xFFF9FBE7)],
    ],
  };

  static const _moodLabels = {
    MoodTheme.calm: 'Calm',
    MoodTheme.cyberpunk: 'Cyber',
    MoodTheme.nature: 'Nature',
  };

  @override
  void initState() {
    super.initState();
    _gradientCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
      value: 0,
    )..forward();

    _clockCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();
  }

  @override
  void dispose() {
    _gradientCtrl.dispose();
    _fadeCtrl.dispose();
    _clockCtrl.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (_dismissing) return;
    _dismissing = true;
    HapticFeedback.lightImpact();
    await AlarmService().completeAlarm(widget.alarmId);
    if (!mounted) return;
    final isFirst = await SettingsService().checkAndMarkFirstCompletion();
    if (mounted) {
      Navigator.of(context).pop();
      if (isFirst) _showFirstCompletionDialog();
    }
  }

  void _showFirstCompletionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('First one down! 🎉'),
        content: const Text(
          "Great start! Sign in to keep your streak safe and sync across all your devices.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }

  String _timeString() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final pairs = _themes[_mood]!;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: AnimatedBuilder(
          animation: _gradientCtrl,
          builder: (_, __) {
            final t = _gradientCtrl.value;
            final c1 = Color.lerp(pairs[0][0], pairs[1][0], t)!;
            final c2 = Color.lerp(pairs[0][1], pairs[1][1], t)!;

            return GestureDetector(
              onVerticalDragUpdate: (d) {
                setState(() => _swipeDy += d.delta.dy);
                if (_swipeDy < -100) _dismiss();
              },
              onVerticalDragEnd: (_) => setState(() => _swipeDy = 0),
              child: FadeTransition(
                opacity: _fadeCtrl,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [c1, c2],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: SafeArea(
                    child: Column(
                      children: [
                        const Spacer(flex: 2),

                        // Clock — rebuilds every second via _clockCtrl
                        AnimatedBuilder(
                          animation: _clockCtrl,
                          builder: (_, __) => Text(
                            _timeString(),
                            style: TextStyle(
                              fontSize: 80,
                              fontWeight: FontWeight.w100,
                              color: Colors.white.withOpacity(0.95),
                              letterSpacing: -3,
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Alarm label card
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 40),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.35),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                          child: Text(
                            widget.content,
                            style: const TextStyle(
                              fontSize: 17,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),

                        const SizedBox(height: 36),

                        // Mood selector chips
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: MoodTheme.values.map((m) {
                            final selected = _mood == m;
                            return GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _mood = m);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOut,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 9,
                                ),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? Colors.white.withOpacity(0.3)
                                      : Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(
                                      selected ? 0.7 : 0.25,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  _moodLabels[m]!,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(
                                      selected ? 1.0 : 0.55,
                                    ),
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.normal,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                        const Spacer(flex: 3),

                        // Swipe-up affordance
                        Transform.translate(
                          offset: Offset(
                            0,
                            (_swipeDy.clamp(-80, 0)).toDouble(),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.keyboard_arrow_up_rounded,
                                color: Colors.white.withOpacity(0.8),
                                size: 36,
                              ),
                              Text(
                                'Swipe up to dismiss',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.65),
                                  fontSize: 14,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
