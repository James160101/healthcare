import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/doctor.dart';
import '../models/patient.dart';
import '../models/patient_data.dart';
import '../models/alert.dart';

class FirebaseService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  final String _deviceId = "PATIENT_001";

  StreamSubscription? _deviceDataSubscription;
  StreamSubscription? _patientHistorySubscription;
  StreamSubscription? _alertsSubscription;
  StreamSubscription? _patientsSubscription;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Doctor? _currentDoctor;
  Doctor? get currentDoctor => _currentDoctor;

  String? patientId; // L'ID du patient logiquement sélectionné

  List<Patient> _allPatients = [];
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
    _deviceDataSubscription?.cancel();
    _patientHistorySubscription?.cancel();
    _alertsSubscription?.cancel();
    _patientsSubscription?.cancel();

    if (user == null) {
      _currentDoctor = null;
      patientId = null;
      _clearPatientData();
      _patients = [];
      _allPatients = [];
    } else {
      await _fetchDoctorProfile(user.uid);
      listenToPatients();
    }
    notifyListeners();
  }

  void listenToPatients() {
    _patientsSubscription?.cancel();
    _patientsSubscription = _database.ref('patients').onValue.listen((event) {
      if (event.snapshot.exists && event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        _allPatients = data.entries
            .where((entry) => entry.key != _deviceId)
            .map((entry) {
              return Patient.fromMap(entry.key, Map<String, dynamic>.from(entry.value as Map));
            }).toList();
        _patients = List.from(_allPatients);
      } else {
        _allPatients = [];
        _patients = [];
      }
      notifyListeners();
    }, onError: (error) {
      _error = "Erreur: $error";
      notifyListeners();
    });
  }

  void selectPatient(String newPatientId) {
    if (patientId == newPatientId) {
      // Si le même patient est sélectionné, on force juste le rechargement
      _clearPatientData();
      _isLoading = true;
      notifyListeners();
    } else {
      patientId = newPatientId;
      _clearPatientData();
      _isLoading = true;
      notifyListeners();
    }

    listenToDeviceAndCopyData();
    listenToPatientHistory();
    listenToAlerts();
  }

  void listenToDeviceAndCopyData() {
    _deviceDataSubscription?.cancel();
    _deviceDataSubscription = _database
        .ref('patients/$_deviceId/measurements')
        .orderByKey()
        .limitToLast(1)
        .onValue
        .listen((event) async {
      if (event.snapshot.exists && event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        final lastEntry = data.entries.first;
        final newMeasurement = PatientData.fromMap(Map<String, dynamic>.from(lastEntry.value as Map));

        if (patientId != null) {
          final patientHistoryRef = _database.ref('patients/$patientId/measurements').push();
          await patientHistoryRef.set(newMeasurement.toMap());
          await _checkForAlerts(newMeasurement);
        }

        _latestData = newMeasurement;
        notifyListeners();
      }
    });
  }

  void listenToPatientHistory() {
    if (patientId == null) return;
    _patientHistorySubscription?.cancel();
    _patientHistorySubscription = _database
        .ref('patients/$patientId/measurements')
        .orderByKey()
        .limitToLast(50)
        .onValue
        .listen((event) {
      _error = null; // Réinitialiser l'erreur en cas de succès
      if (event.snapshot.exists && event.snapshot.value != null) {
        final values = Map<String, dynamic>.from(event.snapshot.value as Map);
        _historyData = values.entries.map((e) {
          final valueMap = Map<String, dynamic>.from(e.value as Map);
          return PatientData.fromMap(valueMap);
        }).toList()..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      } else {
        _historyData = [];
      }
      _isLoading = false;
      notifyListeners();
    }, onError: (err) {
      _error = "Erreur de chargement de l'historique: $err";
       _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> _checkForAlerts(PatientData data) async {
    if (patientId == null) return;

    Patient? patient;
    try {
      patient = _allPatients.firstWhere((p) => p.id == patientId);
    } catch (e) { return; }

    Alert? newAlert;
    String message = '';

    if (data.heartRate > 120 || data.heartRate < 50) {
      message = 'Valeur anormale pour ${patient.name}: ${data.heartRate} BPM. Contacter la famille au ${patient.familyContact}';
      newAlert = Alert(id: 'bpm_${data.timestamp.millisecondsSinceEpoch}', timestamp: data.timestamp, type: 'Fréquence Cardiaque', message: message, level: AlertLevel.Critical);
    } else if (data.spo2 < 90) {
      message = 'Niveau de SpO2 bas pour ${patient.name}: ${data.spo2.toStringAsFixed(0)}%. Contacter la famille au ${patient.familyContact}';
      newAlert = Alert(id: 'spo2_${data.timestamp.millisecondsSinceEpoch}', timestamp: data.timestamp, type: 'Saturation O2', message: message, level: AlertLevel.Critical);
    }

    if (newAlert != null) {
      try {
        DatabaseReference alertRef = _database.ref('patients/$patientId/alerts/${newAlert.id}');
        await alertRef.set(newAlert.toMap());
      } catch (e) { /* Gérer l'erreur silencieusement */ }
    }
  }

  void listenToAlerts() {
    if (patientId == null) return;
    _alertsSubscription?.cancel();
    _alertsSubscription = _database.ref('patients/$patientId/alerts').onValue.listen((event) {
      if (event.snapshot.exists && event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        _alerts = data.values.map((v) => Alert.fromMap(Map<String, dynamic>.from(v as Map))).toList()..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      } else {
        _alerts = [];
      }
      notifyListeners();
    });
  }
  
  void _clearPatientData() {
    _historyData = [];
    _latestData = null;
    _alerts = [];
    _error = null;
    _deviceDataSubscription?.cancel();
    _patientHistorySubscription?.cancel();
  }

  // --- Reste des méthodes ---

  Future<void> addPatient(Patient patient) async {
    try {
      DatabaseReference ref = _database.ref('patients').push();
      await ref.set(patient.toMap());
    } catch (e) {
      throw Exception("Erreur lors de l'ajout du patient: $e");
    }
  }

  Future<void> updatePatient(Patient patient) async {
    try {
      await _database.ref('patients/${patient.id}').update(patient.toMap());
    } catch (e) {
      throw Exception("Erreur lors de la mise à jour: $e");
    }
  }

  Future<void> deletePatient(String patientId) async {
    try {
      await _database.ref('patients/$patientId').remove();
    } catch (e) {
      throw Exception("Erreur lors de la suppression: $e");
    }
  }

  void searchPatients(String query) {
    if (query.isEmpty) {
      _patients = List.from(_allPatients);
    } else {
      _patients = _allPatients
          .where((patient) => patient.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
    }
    notifyListeners();
  }

  Future<void> _fetchDoctorProfile(String uid) async {
    try {
      final snapshot = await _database.ref('doctors/$uid').get();
      if (snapshot.exists) {
        _currentDoctor = Doctor.fromMap(Map<String, dynamic>.from(snapshot.value as Map), uid);
      } else {
        final email = currentUser?.email ?? '';
        final name = email.split('@')[0];
        _currentDoctor = Doctor(uid: uid, name: name, email: email, imageUrl: '');
        await _database.ref('doctors/$uid').set(_currentDoctor!.toMap());
      }
    } catch (e) {
      _error = "Erreur: $e";
      notifyListeners();
    }
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
      throw Exception("Une erreur: $e");
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

  Future<void> signOut() async {
    await _auth.signOut();
    _clearPatientData();
  }

  void _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password': throw Exception('Mot de passe trop faible.');
      case 'email-already-in-use': throw Exception('Cet email est déjà utilisé.');
      default: throw Exception("Erreur d'authentification.");
    }
  }

  @override
  void dispose() {
    _deviceDataSubscription?.cancel();
    _patientHistorySubscription?.cancel();
    _alertsSubscription?.cancel();
    _patientsSubscription?.cancel();
    super.dispose();
  }
}
