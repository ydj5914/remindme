import 'package:flutter/material.dart';

enum RepeatType {
  once, // 한 번만
  daily, // 매일
  weekdays, // 주중 (월-금)
  weekends, // 주말 (토-일)
  custom, // 사용자 지정
}

enum AlarmCategory {
  work, // 업무
  personal, // 개인
  health, // 건강
  other, // 기타
}

enum AlarmSound {
  defaultSound, // 기본
  gentle, // 부드러운
  classic, // 클래식
  digital, // 디지털
  nature, // 자연
}

class AlarmItem {
  final String id;
  final DateTime time;
  final String content;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? completedAt;
  final RepeatType repeatType;
  final List<int>? customDays; // 0=월, 1=화, ..., 6=일
  final int snoozeCount; // 스누즈된 횟수
  final AlarmCategory category; // 카테고리
  final AlarmSound sound; // 알람 소리
  final String? voiceMemoPath; // 음성 메모 경로
  final String? note; // 히스토리 메모/이모지

  AlarmItem({
    required this.id,
    required this.time,
    required this.content,
    required this.isActive,
    DateTime? createdAt,
    this.completedAt,
    this.repeatType = RepeatType.daily,
    this.customDays,
    this.snoozeCount = 0,
    this.category = AlarmCategory.personal,
    this.sound = AlarmSound.defaultSound,
    this.voiceMemoPath,
    this.note,
  }) : createdAt = createdAt ?? DateTime.now();

  // Firestore로부터 데이터 읽기
  factory AlarmItem.fromMap(String id, Map<String, dynamic> data) {
    return AlarmItem(
      id: id,
      time: DateTime.fromMillisecondsSinceEpoch(data['timeMillis'] as int),
      content: data['content'] as String,
      isActive: data['isActive'] as bool? ?? true,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        data['createdAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
      completedAt: data['completedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(data['completedAt'] as int)
          : null,
      repeatType: RepeatType.values.firstWhere(
        (e) => e.name == (data['repeatType'] as String?),
        orElse: () => RepeatType.daily,
      ),
      customDays: data['customDays'] != null
          ? List<int>.from(data['customDays'] as List)
          : null,
      snoozeCount: data['snoozeCount'] as int? ?? 0,
      category: AlarmCategory.values.firstWhere(
        (e) => e.name == (data['category'] as String?),
        orElse: () => AlarmCategory.personal,
      ),
      sound: AlarmSound.values.firstWhere(
        (e) => e.name == (data['sound'] as String?),
        orElse: () => AlarmSound.defaultSound,
      ),
      voiceMemoPath: data['voiceMemoPath'] as String?,
      note: data['note'] as String?,
    );
  }

  // Firestore에 저장할 데이터 변환
  Map<String, dynamic> toMap() {
    return {
      'timeMillis': time.millisecondsSinceEpoch,
      'hour': time.hour,
      'minute': time.minute,
      'content': content,
      'isActive': isActive,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'completedAt': completedAt?.millisecondsSinceEpoch,
      'repeatType': repeatType.name,
      'customDays': customDays,
      'snoozeCount': snoozeCount,
      'category': category.name,
      'sound': sound.name,
      'voiceMemoPath': voiceMemoPath,
      'note': note,
    };
  }

  AlarmItem copyWith({
    String? id,
    DateTime? time,
    String? content,
    bool? isActive,
    DateTime? createdAt,
    DateTime? completedAt,
    RepeatType? repeatType,
    List<int>? customDays,
    int? snoozeCount,
    AlarmCategory? category,
    AlarmSound? sound,
    String? voiceMemoPath,
    String? note,
  }) {
    return AlarmItem(
      id: id ?? this.id,
      time: time ?? this.time,
      content: content ?? this.content,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      repeatType: repeatType ?? this.repeatType,
      customDays: customDays ?? this.customDays,
      snoozeCount: snoozeCount ?? this.snoozeCount,
      category: category ?? this.category,
      sound: sound ?? this.sound,
      voiceMemoPath: voiceMemoPath ?? this.voiceMemoPath,
      note: note ?? this.note,
    );
  }

  int get notificationId => time.millisecondsSinceEpoch ~/ 1000;

  String get repeatLabel {
    switch (repeatType) {
      case RepeatType.once:
        return 'Once';
      case RepeatType.daily:
        return 'Every day';
      case RepeatType.weekdays:
        return 'Weekdays';
      case RepeatType.weekends:
        return 'Weekends';
      case RepeatType.custom:
        if (customDays == null || customDays!.isEmpty) return 'Custom';
        const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        return customDays!.map((d) => dayNames[d]).join(', ');
    }
  }

  bool shouldRingToday() {
    if (repeatType == RepeatType.once) return true;

    final now = DateTime.now();
    final weekday = now.weekday - 1; // 0=월, 6=일

    switch (repeatType) {
      case RepeatType.daily:
        return true;
      case RepeatType.weekdays:
        return weekday >= 0 && weekday <= 4; // 월-금
      case RepeatType.weekends:
        return weekday == 5 || weekday == 6; // 토-일
      case RepeatType.custom:
        return customDays?.contains(weekday) ?? false;
      case RepeatType.once:
        return true;
    }
  }

  String get categoryLabel {
    switch (category) {
      case AlarmCategory.work:
        return 'Work';
      case AlarmCategory.personal:
        return 'Personal';
      case AlarmCategory.health:
        return 'Health';
      case AlarmCategory.other:
        return 'Other';
    }
  }

  IconData get categoryIcon {
    switch (category) {
      case AlarmCategory.work:
        return Icons.work_outline;
      case AlarmCategory.personal:
        return Icons.person_outline;
      case AlarmCategory.health:
        return Icons.favorite_outline;
      case AlarmCategory.other:
        return Icons.label_outline;
    }
  }

  String get soundLabel {
    switch (sound) {
      case AlarmSound.defaultSound:
        return '기본';
      case AlarmSound.gentle:
        return '부드러운';
      case AlarmSound.classic:
        return '클래식';
      case AlarmSound.digital:
        return '디지털';
      case AlarmSound.nature:
        return '자연';
    }
  }

  Color get categoryColor {
    switch (category) {
      case AlarmCategory.work:
        return const Color(0xFF2196F3); // 파란색
      case AlarmCategory.personal:
        return const Color(0xFF9C27B0); // 보라색
      case AlarmCategory.health:
        return const Color(0xFF4CAF50); // 초록색
      case AlarmCategory.other:
        return const Color(0xFF757575); // 회색
    }
  }
}
