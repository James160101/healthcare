import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';

class LocationService extends ChangeNotifier {
  Position? _currentPosition;
  String _statusMessage = "En attente du signal ESP32...";
  
  // Référence à la base de données Firebase Realtime
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  Position? get currentPosition => _currentPosition;
  String get statusMessage => _statusMessage;

  /// Écoute la position envoyée par l'ESP32 via Firebase
  void listenToPatientLocation(String patientId) {
    _statusMessage = "Recherche du signal GPS...";
    notifyListeners();

    // Pour le prototype : on écoute à la fois l'ID spécifique du patient 
    // ET "PATIENT_001" (l'ID par défaut de l'ESP32).
    
    // 1. Essayer d'écouter l'ID du patient (ex: -OdbBP...)
    _listenToPath('patients/$patientId/location');

    // 2. Essayer d'écouter PATIENT_001 (Si l'ESP32 est codé en dur)
    if (patientId != "PATIENT_001") {
       _listenToPath('patients/PATIENT_001/location');
    }
  }

  void _listenToPath(String path) {
    _database.child(path).onValue.listen((event) {
      final data = event.snapshot.value;

      if (data != null && data is Map) {
        try {
          // Conversion sécurisée des données
          final double lat = double.parse(data['latitude'].toString());
          final double lng = double.parse(data['longitude'].toString());

          // On crée un objet Position
          _currentPosition = Position(
            latitude: lat,
            longitude: lng,
            timestamp: DateTime.now(),
            accuracy: 0,
            altitude: 0,
            heading: 0,
            speed: 0,
            speedAccuracy: 0, 
            altitudeAccuracy: 0, 
            headingAccuracy: 0,
          );

          _statusMessage = "Signal reçu ($path) : $lat, $lng";
          notifyListeners();
        } catch (e) {
          // Ignorer les erreurs de parsing silencieuses pour éviter de spammer si un chemin est vide
          // _statusMessage = "Erreur lecture: $e";
          // notifyListeners();
        }
      }
    });
  }

  /// (Ancienne méthode GPS téléphone - conservée au cas où)
  Future<void> getCurrentLocation() async {
      // ... Code GPS téléphone supprimé pour clarté, 
      // car nous utilisons maintenant Firebase/ESP32
  }
}
