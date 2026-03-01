class AlarmItem {
  final String id;
  final DateTime time;
  final String content;
  final bool isActive;
  final DateTime createdAt;

  AlarmItem({
    required this.id,
    required this.time,
    required this.content,
    required this.isActive,
    DateTime? createdAt,
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
    };
  }

  AlarmItem copyWith({
    String? id,
    DateTime? time,
    String? content,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return AlarmItem(
      id: id ?? this.id,
      time: time ?? this.time,
      content: content ?? this.content,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  int get notificationId => time.millisecondsSinceEpoch ~/ 1000;
}
