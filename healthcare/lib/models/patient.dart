class Patient {
  final String id;
  final String name;
  final int age;
  final int height;
  final int weight;
  final String phone;
  final String familyContact;
  final String imageUrl;

  Patient({
    required this.id,
    required this.name,
    required this.age,
    required this.height,
    required this.weight,
    required this.phone,
    required this.familyContact,
    required this.imageUrl,
  });

  factory Patient.fromMap(String id, Map<String, dynamic> data) {
    return Patient(
      id: id,
      name: data['name'] ?? '',
      age: data['age'] ?? 0,
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
      'age': age,
      'height': height,
      'weight': weight,
      'phone': phone,
      'familyContact': familyContact,
      'imageUrl': imageUrl,
    };
  }
}
