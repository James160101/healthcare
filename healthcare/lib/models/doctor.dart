class Doctor {
  final String uid;
  final String name;
  final String email;
  final String? imageUrl;

  Doctor({
    required this.uid,
    required this.name,
    required this.email,
    this.imageUrl,
  });

  factory Doctor.fromMap(Map<String, dynamic> map, String uid) {
    return Doctor(
      uid: uid,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      imageUrl: map['imageUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'imageUrl': imageUrl,
    };
  }
}
