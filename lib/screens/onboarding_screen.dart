import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/settings_service.dart';
import 'main_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final _controller = PageController();
  int _page = 0;

  late AnimationController _chaosCtrl;
  late AnimationController _moodCtrl;
  late AnimationController _ghostCtrl;
  late AnimationController _fadeCtrl;

  @override
  void initState() {
    super.initState();
    _chaosCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _moodCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _ghostCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
      value: 1,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _chaosCtrl.dispose();
    _moodCtrl.dispose();
    _ghostCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _next() {
    HapticFeedback.selectionClick();
    if (_page < 2) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    HapticFeedback.mediumImpact();
    await SettingsService().setOnboardingDone();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const MainScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F14),
      body: Stack(
        children: [
          // Page content
          PageView(
            controller: _controller,
            onPageChanged: (i) {
              HapticFeedback.selectionClick();
              setState(() => _page = i);
            },
            children: [
              _ChaosSlide(ctrl: _chaosCtrl),
              _MoodSlide(ctrl: _moodCtrl),
              _GhostSlide(ctrl: _ghostCtrl),
            ],
          ),

          // Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 24),
                child: Column(
                  children: [
                    // Page indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(3, (i) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _page == i ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _page == i
                                ? _pageColor(_page)
                                : Colors.white24,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 28),

                    // Next / Get Started button
                    GestureDetector(
                      onTap: _next,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          color: _pageColor(_page),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: _pageColor(_page).withOpacity(0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            _page < 2 ? 'Next →' : 'Get Started',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),

                    if (_page < 2) ...[
                      const SizedBox(height: 14),
                      GestureDetector(
                        onTap: _finish,
                        child: Text(
                          'Skip',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.3),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _pageColor(int page) {
    switch (page) {
      case 0:
        return const Color(0xFFCC2233);
      case 1:
        return const Color(0xFF7C3AED);
      default:
        return const Color(0xFF546E7A);
    }
  }
}

// ─── Chaos Slide ──────────────────────────────────────────────────────────────

class _ChaosSlide extends StatelessWidget {
  final AnimationController ctrl;
  const _ChaosSlide({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 60, 32, 140),
        child: Column(
          children: [
            // Animated bouncing circles preview
            SizedBox(
              height: 220,
              child: AnimatedBuilder(
                animation: ctrl,
                builder: (_, __) {
                  final t = ctrl.value;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // Glitch glow background
                      Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFCC2233).withOpacity(0.06),
                        ),
                      ),
                      // 4 bouncing circles
                      ..._circles(t),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 32),

            // Mode badge
            _ModeBadge(
              icon: Icons.bolt,
              label: 'CHAOS MODE',
              color: const Color(0xFFCC2233),
            ),
            const SizedBox(height: 20),

            const Text(
              'The Hard Awakening',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Alarm fires? Pop all the targets first.\nNo targets popped — no dismissal. Simple.',
              style: TextStyle(
                fontSize: 15,
                color: Colors.white.withOpacity(0.6),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _circles(double t) {
    final offsets = [
      Offset(-50 + 20 * sin(t * pi * 2), -40 + 15 * cos(t * pi * 1.3)),
      Offset(55 + 15 * cos(t * pi * 1.7), -35 + 20 * sin(t * pi * 2.1)),
      Offset(-45 + 18 * sin(t * pi * 1.5), 45 + 12 * cos(t * pi * 1.9)),
      Offset(40 + 22 * cos(t * pi * 2.3), 40 + 18 * sin(t * pi * 1.1)),
    ];
    final colors = [
      const Color(0xFFCC2233),
      const Color(0xFFBB8800),
      const Color(0xFFCC2233),
      const Color(0xFFBB8800),
    ];
    return List.generate(4, (i) {
      return Transform.translate(
        offset: offsets[i],
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors[i],
            boxShadow: [
              BoxShadow(
                color: colors[i].withOpacity(0.3),
                blurRadius: 8 + 4 * t,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: 14,
              height: 14,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
            ),
          ),
        ),
      );
    });
  }
}

// ─── Mood Slide ───────────────────────────────────────────────────────────────

class _MoodSlide extends StatelessWidget {
  final AnimationController ctrl;
  const _MoodSlide({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 60, 32, 140),
        child: Column(
          children: [
            SizedBox(
              height: 220,
              child: AnimatedBuilder(
                animation: ctrl,
                builder: (_, __) {
                  final t = ctrl.value;
                  final c1 = Color.lerp(
                    const Color(0xFFB2EBF2),
                    const Color(0xFFE1BEE7),
                    t,
                  )!;
                  final c2 = Color.lerp(
                    const Color(0xFFF8BBD0),
                    const Color(0xFFDCEDC8),
                    t,
                  )!;
                  return Center(
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [c1, c2],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: c1.withOpacity(0.4),
                            blurRadius: 40,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.keyboard_arrow_up_rounded,
                            color: Colors.white.withOpacity(0.8),
                            size: 36,
                          ),
                          Text(
                            'Swipe up',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 32),

            _ModeBadge(
              icon: Icons.auto_awesome,
              label: 'MOOD MODE',
              color: const Color(0xFF7C3AED),
            ),
            const SizedBox(height: 20),

            const Text(
              'The Aesthetic Vibe',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Wake up to a flowing gradient dreamscape.\nChoose Calm, Cyber, or Nature. Swipe up to rise.',
              style: TextStyle(
                fontSize: 15,
                color: Colors.white.withOpacity(0.6),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Ghost Slide ──────────────────────────────────────────────────────────────

class _GhostSlide extends StatelessWidget {
  final AnimationController ctrl;
  const _GhostSlide({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 60, 32, 140),
        child: Column(
          children: [
            SizedBox(
              height: 220,
              child: AnimatedBuilder(
                animation: ctrl,
                builder: (_, __) {
                  final t = ctrl.value;
                  return Center(
                    child: Opacity(
                      opacity: 0.6 + 0.4 * t,
                      child: Container(
                        width: 260,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.07 + 0.05 * t),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.15),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.nightlight_round,
                                  color: Color(0xFF546E7A),
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Ghost Reminder',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.5),
                                    fontSize: 11,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Drink Water',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '09:00 · Every day',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.4),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF546E7A).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Center(
                                child: Text(
                                  'Mark Done',
                                  style: TextStyle(
                                    color: Color(0xFF90A4AE),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 32),

            _ModeBadge(
              icon: Icons.nightlight_round,
              label: 'GHOST MODE',
              color: const Color(0xFF546E7A),
            ),
            const SizedBox(height: 20),

            const Text(
              'The Stress-Free',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'No noise. No vibration. Just a silent nudge\nthat stays on your lock screen until you\'re ready.',
              style: TextStyle(
                fontSize: 15,
                color: Colors.white.withOpacity(0.6),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _ModeBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _ModeBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
