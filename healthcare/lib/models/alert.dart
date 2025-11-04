enum AlertLevel { Warning, Critical }

class Alert {
  final String id;
  final DateTime timestamp;
  final String type;
  final String message;
  final AlertLevel level;

  Alert({
    required this.id,
    required this.timestamp,
    required this.type,
    required this.message,
    required this.level,
  });

  factory Alert.fromMap(Map<String, dynamic> map) {
    return Alert(
      id: map['id'] ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch((map['timestamp'] ?? 0) * 1000),
      type: map['type'] ?? 'Inconnu',
      message: map['message'] ?? '',
      level: (map['level'] as String? ?? '').toLowerCase() == 'critical' 
          ? AlertLevel.Critical 
          : AlertLevel.Warning,
    );
  }
}
