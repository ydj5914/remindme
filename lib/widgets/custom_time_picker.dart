import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomTimePicker extends StatefulWidget {
  final TimeOfDay initialTime;

  const CustomTimePicker({super.key, required this.initialTime});

  static Future<TimeOfDay?> show(
    BuildContext context, {
    required TimeOfDay initialTime,
  }) {
    return showModalBottomSheet<TimeOfDay>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CustomTimePicker(initialTime: initialTime),
    );
  }

  @override
  State<CustomTimePicker> createState() => _CustomTimePickerState();
}

class _CustomTimePickerState extends State<CustomTimePicker> {
  late int _selectedHour;
  late int _selectedMinute;

  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;

  static const double _itemHeight = 64.0;
  static const int _loopCount = 100;

  @override
  void initState() {
    super.initState();
    _selectedHour = widget.initialTime.hour;
    _selectedMinute = widget.initialTime.minute;

    // Center in the middle of the loop
    final hourMid = (_loopCount ~/ 2) * 24 + _selectedHour;
    final minuteMid = (_loopCount ~/ 2) * 60 + _selectedMinute;

    _hourController = FixedExtentScrollController(initialItem: hourMid);
    _minuteController = FixedExtentScrollController(initialItem: minuteMid);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final neon = const Color(0xFF7C3AED);
    final neonGlow = const Color(0xFF9D5FF5);

    return Container(
      height: MediaQuery.of(context).size.height * 0.52,
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F14),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              // Handle bar
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Title
              Text(
                'Set Time',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),

              const SizedBox(height: 32),

              // Wheels
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Selection highlight bar
                    Container(
                      height: _itemHeight,
                      margin: const EdgeInsets.symmetric(horizontal: 32),
                      decoration: BoxDecoration(
                        color: neon.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: neon.withOpacity(0.4),
                          width: 1,
                        ),
                      ),
                    ),

                    // Top fade
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 80,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              const Color(0xFF0F0F14),
                              const Color(0xFF0F0F14).withOpacity(0),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Bottom fade
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 80,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              const Color(0xFF0F0F14),
                              const Color(0xFF0F0F14).withOpacity(0),
                            ],
                          ),
                        ),
                      ),
                    ),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Hour wheel
                        SizedBox(
                          width: 120,
                          child: ListWheelScrollView.useDelegate(
                            controller: _hourController,
                            itemExtent: _itemHeight,
                            physics: const FixedExtentScrollPhysics(),
                            perspective: 0.003,
                            diameterRatio: 2.2,
                            onSelectedItemChanged: (idx) {
                              final h = idx % 24;
                              if (h != _selectedHour) {
                                HapticFeedback.selectionClick();
                                setState(() => _selectedHour = h);
                              }
                            },
                            childDelegate: ListWheelChildBuilderDelegate(
                              builder: (context, index) {
                                final h = index % 24;
                                final isSelected = h == _selectedHour;
                                return Center(
                                  child: Text(
                                    h.toString().padLeft(2, '0'),
                                    style: TextStyle(
                                      fontSize: isSelected ? 42 : 28,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.w300,
                                      color: isSelected
                                          ? neonGlow
                                          : Colors.white.withOpacity(0.25),
                                      letterSpacing: -1,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),

                        // Colon
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            ':',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w200,
                              color: neonGlow.withOpacity(0.6),
                              letterSpacing: -2,
                            ),
                          ),
                        ),

                        // Minute wheel
                        SizedBox(
                          width: 120,
                          child: ListWheelScrollView.useDelegate(
                            controller: _minuteController,
                            itemExtent: _itemHeight,
                            physics: const FixedExtentScrollPhysics(),
                            perspective: 0.003,
                            diameterRatio: 2.2,
                            onSelectedItemChanged: (idx) {
                              final m = idx % 60;
                              if (m != _selectedMinute) {
                                HapticFeedback.selectionClick();
                                setState(() => _selectedMinute = m);
                              }
                            },
                            childDelegate: ListWheelChildBuilderDelegate(
                              builder: (context, index) {
                                final m = index % 60;
                                final isSelected = m == _selectedMinute;
                                return Center(
                                  child: Text(
                                    m.toString().padLeft(2, '0'),
                                    style: TextStyle(
                                      fontSize: isSelected ? 42 : 28,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.w300,
                                      color: isSelected
                                          ? neonGlow
                                          : Colors.white.withOpacity(0.25),
                                      letterSpacing: -1,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 100), // space for floating button
            ],
          ),

          // Floating Save button
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 24,
            left: 32,
            right: 32,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                Navigator.pop(
                  context,
                  TimeOfDay(hour: _selectedHour, minute: _selectedMinute),
                );
              },
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [neon, neonGlow],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: neon.withOpacity(0.45),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '${_selectedHour.toString().padLeft(2, '0')} : ${_selectedMinute.toString().padLeft(2, '0')}  ·  Save',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
