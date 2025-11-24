import './patient_data.dart';

class Patient {
  final String id;
  final String name;
  final DateTime birthDate;
  final int height;
  final int weight;
  final String phone;
  final String familyContact;
  final String address;
  final String imageUrl;
  final String deviceId;
  final PatientData? latestData;

  Patient({
    required this.id,
    required this.name,
    required this.birthDate,
    required this.height,
    required this.weight,
    required this.phone,
    required this.familyContact,
    required this.address,
    required this.imageUrl,
    required this.deviceId,
    this.latestData,
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
      address: data['address'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      deviceId: data['deviceId'] ?? '',
      latestData: data.containsKey('latest') && data['latest'] != null
          ? PatientData.fromMap(Map<String, dynamic>.from(data['latest'] as Map))
          : null,
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
      'address': address,
      'imageUrl': imageUrl,
      'deviceId': deviceId,
    };
  }
}
