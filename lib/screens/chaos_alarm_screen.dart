import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/alarm_service.dart';
import '../services/settings_service.dart';
import 'login_screen.dart';

class ChaosAlarmScreen extends StatefulWidget {
  final String alarmId;
  final String content;

  const ChaosAlarmScreen({
    super.key,
    required this.alarmId,
    required this.content,
  });

  @override
  State<ChaosAlarmScreen> createState() => _ChaosAlarmScreenState();
}

class _TargetData {
  Offset position;
  Offset velocity;
  bool popped;
  final Color color;
  final double size;

  _TargetData({
    required this.position,
    required this.velocity,
    required this.color,
    this.size = 64,
    this.popped = false,
  });
}

class _ChaosAlarmScreenState extends State<ChaosAlarmScreen>
    with TickerProviderStateMixin {
  late AnimationController _moveController;
  late AnimationController _glitchController;

  final List<_TargetData> _targets = [];
  final _random = Random();
  Size _screenSize = Size.zero;
  int _poppedCount = 0;
  static const _targetCount = 4;

  static const _red = Color(0xFFCC2233);
  static const _yellow = Color(0xFFBB8800);

  @override
  void initState() {
    super.initState();
    _moveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..addListener(_tick);

    _glitchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _screenSize = MediaQuery.of(context).size;
      _spawnTargets();
      _moveController.repeat();
      // Start escalating follow-ups in case user ignores the screen
      AlarmService().startEscalatingFollowUps(widget.alarmId);
    });
  }

  void _spawnTargets() {
    _targets.clear();
    final colors = [_red, _yellow, _red, _yellow];
    for (int i = 0; i < _targetCount; i++) {
      _targets.add(
        _TargetData(
          position: Offset(
            40 + _random.nextDouble() * (_screenSize.width - 80),
            140 + _random.nextDouble() * (_screenSize.height - 300),
          ),
          velocity: Offset(
            (_random.nextDouble() * 2 - 1) * 3.5,
            (_random.nextDouble() * 2 - 1) * 3.5,
          ),
          color: colors[i],
        ),
      );
    }
  }

  void _tick() {
    if (!mounted) return;
    setState(() {
      for (final t in _targets) {
        if (t.popped) continue;
        t.position += t.velocity;
        final r = t.size / 2;
        if (t.position.dx < r || t.position.dx > _screenSize.width - r) {
          t.velocity = Offset(-t.velocity.dx, t.velocity.dy);
        }
        if (t.position.dy < 120 + r ||
            t.position.dy > _screenSize.height - 100 - r) {
          t.velocity = Offset(t.velocity.dx, -t.velocity.dy);
        }
      }
    });
  }

  void _popTarget(int idx) {
    if (_targets[idx].popped) return;
    HapticFeedback.heavyImpact();
    setState(() {
      _targets[idx].popped = true;
      _poppedCount++;
    });
    if (_poppedCount >= _targetCount) _dismiss();
  }

  Future<void> _dismiss() async {
    _moveController.stop();
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 200));
    HapticFeedback.heavyImpact();
    await AlarmService().cancelEscalatingFollowUps(widget.alarmId);
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

  @override
  void dispose() {
    _moveController.dispose();
    _glitchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _screenSize = MediaQuery.of(context).size;
    final remaining = _targetCount - _poppedCount;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Glitch scanlines background
            AnimatedBuilder(
              animation: _glitchController,
              builder: (_, __) => CustomPaint(
                size: Size.infinite,
                painter: _ScanlinePainter(_glitchController.value),
              ),
            ),

            // Header
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Column(
                    children: [
                      AnimatedBuilder(
                        animation: _glitchController,
                        builder: (_, __) {
                          final shift = _glitchController.value > 0.6
                              ? 3.0
                              : 0.0;
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              Transform.translate(
                                offset: Offset(-shift, 0),
                                child: const Text(
                                  'WAKE UP',
                                  style: TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0x44CC2233),
                                    letterSpacing: 6,
                                  ),
                                ),
                              ),
                              Transform.translate(
                                offset: Offset(shift, 0),
                                child: const Text(
                                  'WAKE UP',
                                  style: TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0x44BB8800),
                                    letterSpacing: 6,
                                  ),
                                ),
                              ),
                              const Text(
                                'WAKE UP',
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 6,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.content,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.white.withOpacity(0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        remaining > 0
                            ? 'Pop $remaining target${remaining == 1 ? '' : 's'} to dismiss'
                            : 'DISMISSED!',
                        style: const TextStyle(
                          fontSize: 13,
                          color: _yellow,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Bouncing target circles
            ..._targets.asMap().entries.map((e) {
              final i = e.key;
              final t = e.value;
              if (t.popped) return const SizedBox.shrink();
              return Positioned(
                left: t.position.dx - t.size / 2,
                top: t.position.dy - t.size / 2,
                child: GestureDetector(
                  onTapDown: (_) => _popTarget(i),
                  child: _PulsingTarget(color: t.color, size: t.size),
                ),
              );
            }),

            // Bottom progress dots
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_targetCount, (i) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 5),
                        width: i < _poppedCount ? 14 : 10,
                        height: i < _poppedCount ? 14 : 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < _poppedCount ? _yellow : Colors.white24,
                          boxShadow: i < _poppedCount
                              ? [
                                  BoxShadow(
                                    color: _yellow.withOpacity(0.6),
                                    blurRadius: 8,
                                  ),
                                ]
                              : null,
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Pulsing target widget ────────────────────────────────────────────────────

class _PulsingTarget extends StatefulWidget {
  final Color color;
  final double size;
  const _PulsingTarget({required this.color, required this.size});

  @override
  State<_PulsingTarget> createState() => _PulsingTargetState();
}

class _PulsingTargetState extends State<_PulsingTarget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) {
        final scale = 1.0 + _pulse.value * 0.18;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color,
              boxShadow: [
                BoxShadow(
                  color: widget.color.withOpacity(0.35),
                  blurRadius: 10 + _pulse.value * 6,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: widget.size * 0.35,
                height: widget.size * 0.35,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Glitch scanline painter ──────────────────────────────────────────────────

class _ScanlinePainter extends CustomPainter {
  final double value;
  _ScanlinePainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x0DFFFFFF);
    for (double y = 0; y < size.height; y += 4) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), paint);
    }
    if (value > 0.65) {
      final glitch = Paint()..color = const Color(0x12CC2233);
      final top = size.height * (0.2 + value * 0.4);
      canvas.drawRect(Rect.fromLTWH(0, top, size.width, 3), glitch);
    }
  }

  @override
  bool shouldRepaint(_ScanlinePainter old) => old.value != value;
}
