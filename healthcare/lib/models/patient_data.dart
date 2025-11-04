class PatientData {
  final DateTime timestamp;
  final int heartRate;
  final double spo2;

  PatientData({
    required this.timestamp,
    required this.heartRate,
    required this.spo2,
  });

  factory PatientData.fromMap(Map<String, dynamic> map) {
    return PatientData(
      // Correction: Multiplier par 1000 si le timestamp est en secondes
      timestamp: (map.containsKey('timestamp') && map['timestamp'] is int)
          ? DateTime.fromMillisecondsSinceEpoch((map['timestamp'] as int) * 1000)
          : DateTime.now(),
      
      heartRate: (map['heartRate'] as num? ?? 0).toInt(), 
      spo2: (map['spo2'] as num? ?? 0.0).toDouble(),
    );
  }

  // --- Getters for Status --- //

  String get heartRateStatus {
    if (heartRate > 100) return 'Élevé';
    if (heartRate < 60) return 'Faible';
    return 'Normal';
  }

  String get spo2Status {
    if (spo2 < 95) return 'Faible';
    return 'Normal';
  }

  String get status {
    if (isCritical) return 'Critique';
    if (!isNormal) return 'Attention';
    return 'Normal';
  }

  bool get isNormal {
    return heartRateStatus == 'Normal' && spo2Status == 'Normal';
  }

  bool get isCritical {
    return heartRate > 120 || spo2 < 90;
  }
}
