class Patient {
  final String id;
  final String name;
  final DateTime birthDate; // Remplacer l'âge par la date de naissance
  final int height;
  final int weight;
  final String phone;
  final String familyContact;
  final String imageUrl;

  Patient({
    required this.id,
    required this.name,
    required this.birthDate,
    required this.height,
    required this.weight,
    required this.phone,
    required this.familyContact,
    required this.imageUrl,
  });

  // Calculer l'âge dynamiquement
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
      // Convertir le timestamp de la base de données en DateTime
      birthDate: data['birthDate'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(data['birthDate'] as int)
          : DateTime.now(),
      height: data['height'] ?? 0,
      weight: data['weight'] ?? 0,
      phone: data['phone'] ?? '',
      familyContact: data['familyContact'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      // Stocker la date de naissance comme un timestamp
      'birthDate': birthDate.millisecondsSinceEpoch,
      'height': height,
      'weight': weight,
      'phone': phone,
      'familyContact': familyContact,
      'imageUrl': imageUrl,
    };
  }
}
