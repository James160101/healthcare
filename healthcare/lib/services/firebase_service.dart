import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/doctor.dart';
import '../models/patient.dart';
import '../models/patient_data.dart';
import '../models/alert.dart';

class FirebaseService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  StreamSubscription? _historySubscription;
  StreamSubscription? _alertsSubscription;
  StreamSubscription? _patientsSubscription;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Doctor? _currentDoctor;
  Doctor? get currentDoctor => _currentDoctor;

  String? patientId;

  List<Patient> _patients = [];
  List<Patient> get patients => _patients;

  PatientData? _latestData;
  List<PatientData> _historyData = [];
  List<Alert> _alerts = [];
  bool _isLoading = false;
  String? _error;

  PatientData? get latestData => _latestData;
  List<PatientData> get historyData => _historyData;
  List<Alert> get alerts => _alerts;
  bool get isLoading => _isLoading;
  String? get error => _error;

  FirebaseService() {
    authStateChanges.listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(User? user) async {
    _historySubscription?.cancel();
    _alertsSubscription?.cancel();
    _patientsSubscription?.cancel();

    if (user == null) {
      _currentDoctor = null;
      patientId = null;
      _clearPatientData();
      _patients = [];
    } else {
      await _fetchDoctorProfile(user.uid);
      listenToPatients();
    }
    notifyListeners();
  }
  
  void selectPatient(String newPatientId) {
    if (patientId == newPatientId) return;

    patientId = newPatientId;
    _clearPatientData();
    _isLoading = true;
    notifyListeners();

    listenToHistory();
    listenToAlerts();
  }

  void _clearPatientData() {
    _historyData = [];
    _latestData = null;
    _alerts = [];
    _error = null;
  }

  Future<void> addPatient(Patient patient) async {
    try {
      DatabaseReference ref = _database.ref('patients').push();
      await ref.set(patient.toMap());
      notifyListeners(); // Notifie les listeners pour mettre à jour l'interface
    } catch (e) {
      _error = "Failed to add patient: $e";
      notifyListeners();
    }
  }

  void listenToPatients() {
    _patientsSubscription?.cancel();
    _patientsSubscription = _database.ref('patients').onValue.listen((event) {
      if (event.snapshot.exists && event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        _patients = data.entries.map((entry) {
          return Patient.fromMap(entry.key, Map<String, dynamic>.from(entry.value as Map));
        }).toList();
      } else {
        _patients = [];
      }
      notifyListeners();
    }, onError: (error) {
      _error = "Error loading patients: $error";
      notifyListeners();
    });
  }

  void listenToAlerts() {
    if (patientId == null) return;
    _alertsSubscription?.cancel();
    _alertsSubscription = _database
        .ref('patients/$patientId/alerts')
        .onValue
        .listen((event) {
      if (event.snapshot.exists && event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        _alerts = data.values
            .map((v) => Alert.fromMap(Map<String, dynamic>.from(v as Map)))
            .toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      } else {
        _alerts = [];
      }
      notifyListeners();
    });
  }

  Future<void> _fetchDoctorProfile(String uid) async {
    try {
      final snapshot = await _database.ref('doctors/$uid').get();
      if (snapshot.exists) {
        _currentDoctor = Doctor.fromMap(Map<String, dynamic>.from(snapshot.value as Map), uid);
      } else {
        final email = currentUser?.email ?? '';
        final name = email.split('@')[0];
        _currentDoctor = Doctor(uid: uid, name: name, email: email);
        await _database.ref('doctors/$uid').set(_currentDoctor!.toMap());
      }
    } catch (e) {
      _error = "Erreur de récupération du profil: $e";
    }
    notifyListeners();
  }

  Future<void> signUpWithEmailAndPassword(String email, String password, String name) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      User user = userCredential.user!;

      Doctor newUser = Doctor(uid: user.uid, name: name, email: email, imageUrl: '');
      await _database.ref('doctors/${user.uid}').set(newUser.toMap());
      _currentDoctor = newUser;

      _error = null;
      notifyListeners();
    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
    } catch (e) {
      throw Exception("Une erreur inattendue est survenue: $e");
    }
  }

  Future<void> signInWithEmailAndPassword(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      _error = null;
    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  void listenToHistory({int limit = 50}) {
    if (patientId == null) return;

    _isLoading = true;
    _historySubscription?.cancel();
    _historySubscription = _database
        .ref('patients/$patientId/measurements')
        .orderByKey()
        .limitToLast(limit)
        .onValue
        .listen((event) async { 
      _error = null;
      if (event.snapshot.value != null) {
        final values = Map<String, dynamic>.from(event.snapshot.value as Map);
        _historyData = values.entries.map((e) {
          final valueMap = Map<String, dynamic>.from(e.value as Map);
          return PatientData.fromMap(valueMap);
        }).toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
        
        if (_historyData.isNotEmpty) {
          _latestData = _historyData.first;
          await _checkForAlerts(_latestData!);
        }

      } else {
        _historyData = [];
        _latestData = null;
      }
      _isLoading = false;
      notifyListeners();
    }, onError: (error) {
      _error = 'Erreur de chargement de l\'historique: $error';
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> _checkForAlerts(PatientData data) async {
    if (patientId == null) return;

    Alert? newAlert;

    if (data.heartRate > 120 || data.heartRate < 50) {
      newAlert = Alert(
        id: 'bpm_${data.timestamp.millisecondsSinceEpoch}',
        timestamp: data.timestamp,
        type: 'Fréquence Cardiaque',
        message: 'Valeur anormale détectée: ${data.heartRate} BPM',
        level: AlertLevel.Critical,
      );
    }
    else if (data.spo2 < 90) {
      newAlert = Alert(
        id: 'spo2_${data.timestamp.millisecondsSinceEpoch}',
        timestamp: data.timestamp,
        type: 'Saturation O2',
        message: 'Niveau de SpO2 dangereusement bas: ${data.spo2}%',
        level: AlertLevel.Critical,
      );
    }

    if (newAlert != null) {
      try {
        DatabaseReference alertRef = _database.ref('patients/$patientId/alerts/${newAlert.id}');
        await alertRef.set(newAlert.toMap());
      } catch (e) {
        print("Erreur lors de l'enregistrement de l'alerte: $e");
      }
    }
  }

  Future<void> loadHistory({int limit = 50}) async {
    if (patientId == null) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final snapshot = await _database
          .ref('patients/$patientId/measurements')
          .orderByKey()
          .limitToLast(limit)
          .get();

      if (snapshot.value != null) {
        final values = Map<String, dynamic>.from(snapshot.value as Map);
        _historyData = values.entries.map((e) {
          final valueMap = Map<String, dynamic>.from(e.value as Map);
           return PatientData.fromMap(valueMap);
        }).toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

        _latestData = _historyData.isNotEmpty ? _historyData.first : null;
      } else {
        _historyData = [];
        _latestData = null;
      }
    } catch (e) {
      _error = "Erreur de chargement des données: $e";
    }

    _isLoading = false;
    notifyListeners();
  }

  Map<String, dynamic> getStatistics() {
    if (_historyData.isEmpty) {
      return {
        'avgHeartRate': 0, 'minHeartRate': 0, 'maxHeartRate': 0,
        'avgSpo2': 0.0, 'minSpo2': 0.0, 'maxSpo2': 0.0,
      };
    }

    final heartRates = _historyData.map((d) => d.heartRate).toList();
    final spo2Values = _historyData.map((d) => d.spo2).toList();

    return {
      'avgHeartRate': (heartRates.reduce((a, b) => a + b) / heartRates.length).round(),
      'minHeartRate': heartRates.reduce((a, b) => a < b ? a : b),
      'maxHeartRate': heartRates.reduce((a, b) => a > b ? a : b),
      'avgSpo2': spo2Values.reduce((a, b) => a + b) / spo2Values.length,
      'minSpo2': spo2Values.reduce((a, b) => a < b ? a : b),
      'maxSpo2': spo2Values.reduce((a, b) => a > b ? a : b),
    };
  }

  void _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        throw Exception('Le mot de passe fourni est trop faible.');
      case 'email-already-in-use':
        throw Exception('Un compte existe déjà pour cet email.');
      case 'user-not-found':
        throw Exception('Aucun utilisateur trouvé pour cet email.');
      case 'wrong-password':
        throw Exception('Mot de passe incorrect.');
      case 'invalid-email':
        throw Exception("L'adresse email n'est pas valide.");
      default:
        throw Exception("Erreur d'authentification: ${e.message}");
    }
  }

  @override
  void dispose() {
    _historySubscription?.cancel();
    _alertsSubscription?.cancel();
    _patientsSubscription?.cancel();
    super.dispose();
  }
}
