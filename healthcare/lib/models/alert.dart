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

  // Ajout de la méthode toMap pour la sérialisation vers Firebase
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      // Enregistrement du timestamp en secondes, comme le reste des données
      'timestamp': timestamp.millisecondsSinceEpoch ~/ 1000,
      'type': type,
      'message': message,
      'level': level.name.toLowerCase(), // 'critical' ou 'warning'
    };
  }
}
