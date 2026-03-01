enum RepeatType {
  once, // 한 번만
  daily, // 매일
  weekdays, // 주중 (월-금)
  weekends, // 주말 (토-일)
  custom, // 사용자 지정
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
    );
  }

  int get notificationId => time.millisecondsSinceEpoch ~/ 1000;

  String get repeatLabel {
    switch (repeatType) {
      case RepeatType.once:
        return '한 번만';
      case RepeatType.daily:
        return '매일';
      case RepeatType.weekdays:
        return '주중';
      case RepeatType.weekends:
        return '주말';
      case RepeatType.custom:
        if (customDays == null || customDays!.isEmpty) return '사용자 지정';
        final dayNames = ['월', '화', '수', '목', '금', '토', '일'];
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
}
