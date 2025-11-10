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

  String? patientId;

  List<Patient> _allPatients = [];
  List<Patient> _patients = [];
  List<Patient> get patients => _patients;

  PatientData? _latestData;
  List<PatientData> _historyData = [];
  List<Alert> _alerts = [];
  int _unreadAlertsCount = 0; // Compteur pour les alertes non lues

  PatientData? get latestData => _latestData;
  List<PatientData> get historyData => _historyData;
  List<Alert> get alerts => _alerts;
  int get unreadAlertsCount => _unreadAlertsCount;
  bool _isLoading = false;
  String? _error;

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
    });
  }

  void selectPatient(String newPatientId) {
    if (patientId == newPatientId) {
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
      _error = null;
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
      _error = "Erreur: $err";
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
      newAlert = Alert(id: 'bpm_${data.timestamp.millisecondsSinceEpoch}', timestamp: data.timestamp, type: 'Fréquence Cardiaque', message: message, level: AlertLevel.Critical, isRead: false);
    } else if (data.spo2 < 90) {
      message = 'Niveau de SpO2 bas pour ${patient.name}: ${data.spo2.toStringAsFixed(0)}%. Contacter la famille au ${patient.familyContact}';
      newAlert = Alert(id: 'spo2_${data.timestamp.millisecondsSinceEpoch}', timestamp: data.timestamp, type: 'Saturation O2', message: message, level: AlertLevel.Critical, isRead: false);
    }

    if (newAlert != null) {
      try {
        DatabaseReference alertRef = _database.ref('patients/$patientId/alerts/${newAlert.id}');
        await alertRef.set(newAlert.toMap());
      } catch (e) { /* ... */ }
    }
  }

  void listenToAlerts() {
    if (patientId == null) return;

    _alertsSubscription?.cancel();
    _alertsSubscription = _database.ref('patients/$patientId/alerts').onValue.listen((event) {
      if (event.snapshot.exists && event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        _alerts = data.values.map((v) => Alert.fromMap(Map<String, dynamic>.from(v as Map))).toList()..sort((a, b) => b.timestamp.compareTo(a.timestamp));
        _unreadAlertsCount = _alerts.where((alert) => !alert.isRead).length;
      } else {
        _alerts = [];
        _unreadAlertsCount = 0;
      }
      notifyListeners();
    });
  }

  void markAlertsAsRead() {
    if (patientId == null) return;
    for (var alert in _alerts) {
      if (!alert.isRead) {
        _database.ref('patients/$patientId/alerts/${alert.id}').update({'isRead': true});
      }
    }
    _unreadAlertsCount = 0;
    notifyListeners();
  }
  
  void _clearPatientData() {
    _historyData = [];
    _latestData = null;
    _alerts = [];
    _unreadAlertsCount = 0;
    _error = null;
    _deviceDataSubscription?.cancel();
    _patientHistorySubscription?.cancel();
  }

  // --- Reste des méthodes ---
  Future<void> addPatient(Patient patient) async { /*...*/ }
  Future<void> updatePatient(Patient patient) async { /*...*/ }
  Future<void> deletePatient(String patientId) async { /*...*/ }
  void searchPatients(String query) { /*...*/ }
  Future<void> _fetchDoctorProfile(String uid) async { /*...*/ }
  Future<void> signUpWithEmailAndPassword(String email, String password, String name) async { /*...*/ }
  Future<void> signInWithEmailAndPassword(String email, String password) async { /*...*/ }
  Future<void> signOut() async { /*...*/ }
  void _handleAuthError(FirebaseAuthException e) { /*...*/ }

  @override
  void dispose() {
    _deviceDataSubscription?.cancel();
    _patientHistorySubscription?.cancel();
    _alertsSubscription?.cancel();
    _patientsSubscription?.cancel();
    super.dispose();
  }
}
