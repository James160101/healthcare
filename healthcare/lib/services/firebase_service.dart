import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/doctor.dart';
import '../models/patient_data.dart';
import '../models/alert.dart';

class FirebaseService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  StreamSubscription? _historySubscription;
  StreamSubscription? _alertsSubscription;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Doctor? _currentDoctor;
  Doctor? get currentDoctor => _currentDoctor;

  String? patientId;

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

    if (user == null) {
      _currentDoctor = null;
      _historyData = [];
      _latestData = null;
      _alerts = [];
      patientId = null;
    } else {
      patientId = 'PATIENT_001';
      await _fetchDoctorProfile(user.uid);
      listenToHistory();
      listenToAlerts();
    }
    notifyListeners();
  }

  void listenToAlerts() {
    if (patientId == null) return;
    _alertsSubscription = _database
        .ref('patients/$patientId/alerts')
        .onValue
        .listen((event) {
      if (event.snapshot.exists && event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        final List<Alert> tempAlerts = [];
        for (var value in data.values) {
          try {
            tempAlerts.add(Alert.fromMap(Map<String, dynamic>.from(value as Map)));
          } catch (e) {
            print("Erreur de parsing d'une alerte, donnée ignorée: $e");
          }
        }
        _alerts = tempAlerts..sort((a, b) => b.timestamp.compareTo(a.timestamp));
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
        _currentDoctor = Doctor(uid: uid, name: currentUser?.email?.split('@')[0] ?? 'Utilisateur', email: currentUser?.email ?? '');
      }
    } catch (e) {
      _error = "Erreur de récupération du profil: $e";
    }
    notifyListeners();
  }

  Future<void> signUpWithEmailAndPassword(String email, String password, String name, File image) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User user = userCredential.user!;

      String imageUrl = await _uploadProfileImage(user.uid, image);
      
      Doctor newUser = Doctor(uid: user.uid, name: name, email: email, imageUrl: imageUrl);
      await _database.ref('doctors/${user.uid}').set(newUser.toMap());
      _currentDoctor = newUser;

      await _database.ref('patients/${user.uid}').set({'profile': {'name': name, 'email': email}});

      _error = null;
      notifyListeners();
    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
    } catch (e) {
      throw Exception("Une erreur inattendue est survenue: $e");
    }
  }

  Future<String> _uploadProfileImage(String uid, File image) async {
    Reference storageRef = _storage.ref().child('profile_images').child('$uid.jpg');
    UploadTask uploadTask = storageRef.putFile(image);
    TaskSnapshot snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  Future<void> signInWithEmailAndPassword(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _error = null;
      notifyListeners();
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
        .listen((event) {
      _error = null;
      if (event.snapshot.value != null) {
        final values = Map<String, dynamic>.from(event.snapshot.value as Map);
        _historyData = values.entries.map((e) {
          final valueMap = Map<String, dynamic>.from(e.value as Map);
          if (valueMap.containsKey('timestamp') && valueMap['timestamp'] is int) {
             return PatientData.fromMap(valueMap);
          }
          return null;
        }).whereType<PatientData>().toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
        
        _latestData = _historyData.isNotEmpty ? _historyData.first : null;
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
          if (valueMap.containsKey('timestamp') && valueMap['timestamp'] is int) {
             return PatientData.fromMap(valueMap);
          }
           return null;
        }).whereType<PatientData>().toList()
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
    super.dispose();
  }
}
