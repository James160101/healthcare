class Patient {
  final String id;
  final String name;
  final DateTime birthDate;
  final int height;
  final int weight;
  final String phone;
  final String familyContact;
  final String imageUrl;
  final String deviceId; // ID de l'appareil (ESP32) associé

  Patient({
    required this.id,
    required this.name,
    required this.birthDate,
    required this.height,
    required this.weight,
    required this.phone,
    required this.familyContact,
    required this.imageUrl,
    required this.deviceId,
  });

  int get age {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month || (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  factory Patient.fromMap(String id, Map<String, dynamic> data) {
    return Patient(
      id: id,
      name: data['name'] ?? '',
      birthDate: data['birthDate'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(data['birthDate'] as int)
          : DateTime.now(),
      height: data['height'] ?? 0,
      weight: data['weight'] ?? 0,
      phone: data['phone'] ?? '',
      familyContact: data['familyContact'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      deviceId: data['deviceId'] ?? '', // Récupérer l'ID de l'appareil
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'birthDate': birthDate.millisecondsSinceEpoch,
      'height': height,
      'weight': weight,
      'phone': phone,
      'familyContact': familyContact,
      'imageUrl': imageUrl,
      'deviceId': deviceId, // Sauvegarder l'ID de l'appareil
    };
  }
}
