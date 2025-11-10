enum AlertLevel { Info, Warning, Critical }

class Alert {
  final String id;
  final DateTime timestamp;
  final String type;
  final String message;
  final AlertLevel level;
  final bool isRead;

  Alert({
    required this.id,
    required this.timestamp,
    required this.type,
    required this.message,
    required this.level,
    this.isRead = false,
  });

  factory Alert.fromMap(Map<String, dynamic> map) {
    return Alert(
      id: map['id'] ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch((map['timestamp'] as int) * 1000),
      type: map['type'] ?? '',
      message: map['message'] ?? '',
      level: AlertLevel.values.firstWhere((e) => e.toString() == map['level'], orElse: () => AlertLevel.Info),
      isRead: map['isRead'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': timestamp.millisecondsSinceEpoch ~/ 1000,
      'type': type,
      'message': message,
      'level': level.toString(),
      'isRead': isRead,
    };
  }
}
