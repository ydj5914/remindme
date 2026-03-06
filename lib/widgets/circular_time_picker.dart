import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum _PickerMode { hour, minute }

class CircularTimePicker extends StatefulWidget {
  final TimeOfDay initialTime;

  const CircularTimePicker({super.key, required this.initialTime});

  static Future<TimeOfDay?> show(
    BuildContext context, {
    TimeOfDay? initialTime,
  }) {
    return showModalBottomSheet<TimeOfDay>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          CircularTimePicker(initialTime: initialTime ?? TimeOfDay.now()),
    );
  }

  @override
  State<CircularTimePicker> createState() => _CircularTimePickerState();
}

class _CircularTimePickerState extends State<CircularTimePicker>
    with SingleTickerProviderStateMixin {
  late int _hour;
  late int _minute;
  _PickerMode _mode = _PickerMode.hour;
  late AnimationController _fadeCtrl;

  static const _accent = Color(0xFF7C3AED);
  static const _dialSize = 264.0;

  @override
  void initState() {
    super.initState();
    _hour = widget.initialTime.hour;
    _minute = widget.initialTime.minute;
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    )..value = 1;
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _handleDialInteraction(Offset localPos) {
    const center = Offset(_dialSize / 2, _dialSize / 2);
    final angle = atan2(localPos.dy - center.dy, localPos.dx - center.dx);
    final degrees = (angle * 180 / pi + 90 + 360) % 360;

    if (_mode == _PickerMode.hour) {
      final raw = (degrees / 30).round() % 12;
      final newHour = _hour >= 12 ? raw + 12 : raw;
      if (newHour != _hour) {
        HapticFeedback.selectionClick();
        setState(() => _hour = newHour);
      }
    } else {
      final newMin = (degrees / 6).round() % 60;
      if (newMin != _minute) {
        HapticFeedback.selectionClick();
        setState(() => _minute = newMin);
      }
    }
  }

  void _switchMode(_PickerMode mode) {
    if (_mode == mode) return;
    HapticFeedback.lightImpact();
    _fadeCtrl.forward(from: 0);
    setState(() => _mode = mode);
  }

  void _toggleAmPm() {
    HapticFeedback.selectionClick();
    setState(() => _hour = _hour >= 12 ? _hour - 12 : _hour + 12);
  }

  @override
  Widget build(BuildContext context) {
    final isAm = _hour < 12;
    final displayHour = _hour % 12 == 0 ? 12 : _hour % 12;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF16161E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 28),

          // ── Time display ──────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _TimeSegment(
                value: displayHour.toString().padLeft(2, '0'),
                selected: _mode == _PickerMode.hour,
                onTap: () => _switchMode(_PickerMode.hour),
              ),
              Text(
                ':',
                style: TextStyle(
                  fontSize: 54,
                  fontWeight: FontWeight.w100,
                  color: Colors.white.withOpacity(0.5),
                  height: 1,
                ),
              ),
              _TimeSegment(
                value: _minute.toString().padLeft(2, '0'),
                selected: _mode == _PickerMode.minute,
                onTap: () => _switchMode(_PickerMode.minute),
              ),
              const SizedBox(width: 16),
              // AM / PM
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _AmPmChip(label: 'AM', active: isAm, onTap: _toggleAmPm),
                  const SizedBox(height: 6),
                  _AmPmChip(label: 'PM', active: !isAm, onTap: _toggleAmPm),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),

          // ── Circular dial ─────────────────────────────────────────────
          SizedBox(
            width: _dialSize,
            height: _dialSize,
            child: GestureDetector(
              onPanUpdate: (d) => _handleDialInteraction(d.localPosition),
              onTapDown: (d) => _handleDialInteraction(d.localPosition),
              child: FadeTransition(
                opacity: _fadeCtrl,
                child: CustomPaint(
                  painter: _DialPainter(
                    mode: _mode,
                    hour: _hour % 12,
                    minute: _minute,
                    accent: _accent,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // ── Buttons ───────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _accent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    Navigator.pop(
                      context,
                      TimeOfDay(hour: _hour, minute: _minute),
                    );
                  },
                  child: const Text('Set Time'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Time segment tap target ───────────────────────────────────────────────────

class _TimeSegment extends StatelessWidget {
  final String value;
  final bool selected;
  final VoidCallback onTap;

  static const _accent = Color(0xFF7C3AED);

  const _TimeSegment({
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? _accent.withOpacity(0.22)
              : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          value,
          style: TextStyle(
            fontSize: 56,
            fontWeight: FontWeight.w200,
            color: selected ? Colors.white : Colors.white.withOpacity(0.55),
            height: 1,
          ),
        ),
      ),
    );
  }
}

// ── AM / PM chip ──────────────────────────────────────────────────────────────

class _AmPmChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _AmPmChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active ? Colors.white.withOpacity(0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: active ? FontWeight.w700 : FontWeight.normal,
            color: active ? Colors.white : Colors.white38,
          ),
        ),
      ),
    );
  }
}

// ── Dial painter ──────────────────────────────────────────────────────────────

class _DialPainter extends CustomPainter {
  final _PickerMode mode;
  final int hour; // 0–11
  final int minute; // 0–59
  final Color accent;

  const _DialPainter({
    required this.mode,
    required this.hour,
    required this.minute,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;

    // Background circle
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white.withOpacity(0.06)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white.withOpacity(0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Selected angle
    final double selectedFraction = mode == _PickerMode.hour
        ? hour / 12.0
        : minute / 60.0;
    final double selectedAngle = selectedFraction * 2 * pi - pi / 2;

    // Accent arc
    if (selectedFraction > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        selectedFraction * 2 * pi,
        false,
        Paint()
          ..color = accent.withOpacity(0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }

    // Handle position
    final handlePos = Offset(
      center.dx + radius * cos(selectedAngle),
      center.dy + radius * sin(selectedAngle),
    );

    // Line from center to handle
    canvas.drawLine(
      center,
      handlePos,
      Paint()
        ..color = accent.withOpacity(0.4)
        ..strokeWidth = 1.5,
    );

    // Center dot
    canvas.drawCircle(center, 5, Paint()..color = accent);

    // Handle circle (outer glow)
    canvas.drawCircle(handlePos, 20, Paint()..color = accent.withOpacity(0.3));
    // Handle circle (solid)
    canvas.drawCircle(handlePos, 16, Paint()..color = accent);
    // Handle inner dot
    canvas.drawCircle(
      handlePos,
      5,
      Paint()..color = Colors.white.withOpacity(0.9),
    );

    // Labels
    final tp = TextPainter(textDirection: TextDirection.ltr);
    final labelRadius = radius - 32;

    if (mode == _PickerMode.hour) {
      for (int i = 0; i < 12; i++) {
        final a = (i / 12) * 2 * pi - pi / 2;
        final pos = Offset(
          center.dx + labelRadius * cos(a),
          center.dy + labelRadius * sin(a),
        );
        final isActive = i == hour;
        tp.text = TextSpan(
          text: i == 0 ? '12' : '$i',
          style: TextStyle(
            fontSize: 15,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
            color: isActive ? Colors.white : Colors.white38,
          ),
        );
        tp.layout();
        tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
      }
    } else {
      // 5-min labels
      for (int i = 0; i < 12; i++) {
        final min = i * 5;
        final a = (min / 60) * 2 * pi - pi / 2;
        final pos = Offset(
          center.dx + labelRadius * cos(a),
          center.dy + labelRadius * sin(a),
        );
        final isActive = (minute / 5).round() % 12 == i;
        tp.text = TextSpan(
          text: min.toString().padLeft(2, '0'),
          style: TextStyle(
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
            color: isActive ? Colors.white : Colors.white38,
          ),
        );
        tp.layout();
        tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
      }

      // Minute dots for non-5 positions
      final dotRadius = radius - 14;
      for (int i = 0; i < 60; i++) {
        if (i % 5 == 0) continue;
        final a = (i / 60) * 2 * pi - pi / 2;
        final pos = Offset(
          center.dx + dotRadius * cos(a),
          center.dy + dotRadius * sin(a),
        );
        canvas.drawCircle(
          pos,
          i == minute ? 3.5 : 1.5,
          Paint()
            ..color = i == minute ? accent : Colors.white.withOpacity(0.18),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.mode != mode || old.hour != hour || old.minute != minute;
}
