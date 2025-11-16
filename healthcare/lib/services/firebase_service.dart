import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/doctor.dart';
import '../models/patient.dart';
import '../models/patient_data.dart';
import '../models/alert.dart';

enum HistoryRange { day, week, month, all }

class FirebaseService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  final List<String> _knownDeviceIds = ["PATIENT_001"];

  StreamSubscription? _deviceDataSubscription;
  StreamSubscription? _alertsSubscription;
  StreamSubscription? _patientsSubscription;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Doctor? _currentDoctor;
  Doctor? get currentDoctor => _currentDoctor;

  String? patientId;

  List<Patient> _allPatients = [];
  List<Patient> _patients = [];
  List<String> _deviceIds = [];

  List<Patient> get patients => _patients;
  List<String> get deviceIds => _deviceIds;

  PatientData? _latestData;
  List<PatientData> _fullHistoryData = [];
  List<PatientData> _historyData = [];
  List<Alert> _alerts = [];
  int _unreadAlertsCount = 0;

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
      listenToPatientsAndDevices();
    }
    notifyListeners();
  }

  void listenToPatientsAndDevices() {
    _patientsSubscription?.cancel();
    _patientsSubscription = _database.ref('patients').onValue.listen((event) {
      if (event.snapshot.exists && event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        List<Patient> tempPatients = [];
        List<String> tempDevices = [];
        data.forEach((key, value) {
          if (_knownDeviceIds.contains(key)) {
            tempDevices.add(key);
          } else {
            tempPatients.add(Patient.fromMap(key, Map<String, dynamic>.from(value as Map)));
          }
        });
        _allPatients = tempPatients;
        _patients = List.from(_allPatients);
        _deviceIds = tempDevices;
      } else {
        _allPatients = [];
        _patients = [];
        _deviceIds = [];
      }
      notifyListeners();
    });
  }

  Patient? getPatientById(String id) {
    try {
      return _allPatients.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }

  void selectPatient(String newPatientId) {
    patientId = newPatientId;
    _clearPatientData();
    _isLoading = true;
    notifyListeners();
    listenToDeviceData();
    listenToAlerts();
  }

  void listenToDeviceData() {
    if (patientId == null) return;
    final patient = getPatientById(patientId!);
    if (patient == null || patient.deviceId.isEmpty) {
      _error = "Ce patient n'a pas d'appareil assigné.";
      _isLoading = false;
      notifyListeners();
      return;
    }
    _deviceDataSubscription?.cancel();
    _deviceDataSubscription = _database.ref('patients/${patient.deviceId}/measurements').orderByKey().onValue.listen((event) async {
      _error = null;
      if (event.snapshot.exists && event.snapshot.value != null) {
        final values = Map<String, dynamic>.from(event.snapshot.value as Map);
        _fullHistoryData = values.entries.map((e) => PatientData.fromMap(Map<String, dynamic>.from(e.value as Map))).toList()..sort((a, b) => b.timestamp.compareTo(a.timestamp));
        filterHistoryByRange(HistoryRange.all); // Appliquer le filtre par défaut
        if (_historyData.isNotEmpty) {
          _latestData = _historyData.first;
        }
      } else {
        _fullHistoryData = [];
        _historyData = [];
        _latestData = null;
      }
      _isLoading = false;
      notifyListeners();
    }, onError: (err) {
      _error = "Erreur: $err";
      _isLoading = false;
      notifyListeners();
    });
  }

  void filterHistoryByRange(HistoryRange range) {
    final now = DateTime.now();
    DateTime startDate;
    switch (range) {
      case HistoryRange.day: startDate = now.subtract(const Duration(days: 1)); break;
      case HistoryRange.week: startDate = now.subtract(const Duration(days: 7)); break;
      case HistoryRange.month: startDate = now.subtract(const Duration(days: 30)); break;
      case HistoryRange.all:
        _historyData = List.from(_fullHistoryData);
        notifyListeners();
        return;
    }
    _historyData = _fullHistoryData.where((record) => record.timestamp.isAfter(startDate)).toList();
    notifyListeners();
  }

  Map<String, dynamic> getStatistics() {
    if (historyData.isEmpty) return {'avgBpm': 0, 'minBpm': 0, 'maxBpm': 0, 'avgSpo2': 0.0, 'minSpo2': 0.0, 'maxSpo2': 0.0,};
    final bpms = historyData.map((d) => d.heartRate).toList();
    final spo2s = historyData.map((d) => d.spo2).toList();
    return {
      'avgBpm': (bpms.reduce((a, b) => a + b) / bpms.length).round(),
      'minBpm': bpms.reduce((a, b) => a < b ? a : b),
      'maxBpm': bpms.reduce((a, b) => a > b ? a : b),
      'avgSpo2': spo2s.reduce((a, b) => a + b) / spo2s.length,
      'minSpo2': spo2s.reduce((a, b) => a < b ? a : b),
      'maxSpo2': spo2s.reduce((a, b) => a > b ? a : b),
    };
  }

  Future<void> _checkForAlerts(PatientData data) async {
    if (patientId == null) return;
    Patient? patient = getPatientById(patientId!);
    if (patient == null) return;
    Alert? newAlert;
    if (data.heartRate > 120 || data.heartRate < 50) {
      newAlert = Alert(id: 'bpm_${data.timestamp.millisecondsSinceEpoch}', timestamp: data.timestamp, type: 'Fréquence Cardiaque', message: 'Valeur anormale pour ${patient.name}: ${data.heartRate} BPM. Contacter la famille au ${patient.familyContact}', level: AlertLevel.Critical, isRead: false);
    } else if (data.spo2 < 90) {
      newAlert = Alert(id: 'spo2_${data.timestamp.millisecondsSinceEpoch}', timestamp: data.timestamp, type: 'Saturation O2', message: 'Niveau de SpO2 bas pour ${patient.name}: ${data.spo2.toStringAsFixed(0)}%. Contacter la famille au ${patient.familyContact}', level: AlertLevel.Critical, isRead: false);
    }
    if (newAlert != null) {
      try {
        await _database.ref('patients/$patientId/alerts/${newAlert.id}').set(newAlert.toMap());
      } catch (e) { /* Gérer l'erreur */ }
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
  }
  
  void _clearPatientData() {
    _historyData = [];
    _fullHistoryData = [];
    _latestData = null;
    _alerts = [];
    _unreadAlertsCount = 0;
    _error = null;
    _deviceDataSubscription?.cancel();
  }

  Future<void> addPatient(Patient patient) async {
    try {
      await _database.ref('patients').push().set(patient.toMap());
    } catch (e) { throw Exception("Erreur: $e"); }
  }

  Future<void> updatePatient(Patient patient) async {
    try {
      await _database.ref('patients/${patient.id}').update(patient.toMap());
    } catch (e) { throw Exception("Erreur: $e"); }
  }

  Future<void> deletePatient(String patientId) async {
    try {
      await _database.ref('patients/$patientId').remove();
    } catch (e) { throw Exception("Erreur: $e"); }
  }

  void searchPatients(String query) {
    _patients = query.isEmpty ? List.from(_allPatients) : _allPatients.where((p) => p.name.toLowerCase().contains(query.toLowerCase())).toList();
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
    } catch (e) { _error = "Erreur: $e"; notifyListeners(); }
  }

  Future<void> signUpWithEmailAndPassword(String email, String password, String name) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      Doctor newUser = Doctor(uid: userCredential.user!.uid, name: name, email: email, imageUrl: '');
      await _database.ref('doctors/${newUser.uid}').set(newUser.toMap());
      _currentDoctor = newUser;
      notifyListeners();
    } on FirebaseAuthException catch (e) { _handleAuthError(e); } catch (e) { throw Exception("Erreur: $e"); }
  }

  Future<void> signInWithEmailAndPassword(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    _clearPatientData();
  }

  void _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found': throw Exception('Aucun utilisateur trouvé.');
      case 'wrong-password': throw Exception('Mot de passe incorrect.');
      case 'invalid-email': throw Exception('Email non valide.');
      case 'weak-password': throw Exception('Mot de passe trop faible.');
      case 'email-already-in-use': throw Exception('Cet email est déjà utilisé.');
      default: throw Exception("Erreur d'authentification.");
    }
  }

  @override
  void dispose() {
    _deviceDataSubscription?.cancel();
    _alertsSubscription?.cancel();
    _patientsSubscription?.cancel();
    super.dispose();
  }
}
